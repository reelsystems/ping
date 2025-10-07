# ForgeRock Identity Platform - Zero Trust Deployment Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Initial Setup - Windows Server 2019](#initial-setup---windows-server-2019)
4. [Private Docker Registry Setup (Air-Gapped)](#private-docker-registry-setup-air-gapped)
5. [Directory Structure Creation](#directory-structure-creation)
6. [Configuration](#configuration)
7. [Deployment Steps](#deployment-steps)
8. [Active Directory Integration](#active-directory-integration)
9. [ServiceNow Integration](#servicenow-integration)
10. [DoD Zero Trust Hardening](#dod-zero-trust-hardening)
11. [Verification & Testing](#verification--testing)
12. [Backup & Recovery](#backup--recovery)
13. [Troubleshooting](#troubleshooting)
14. [Migration to Air-Gapped Environment](#migration-to-air-gapped-environment)

---

## Overview

This deployment configures the ForgeRock Identity Platform (now Ping Identity) for Zero Trust architecture in compliance with DoD security requirements. The stack includes:

- **PingDS (ForgeRock Directory Services)**: LDAP directory and data store
- **PingAM (ForgeRock Access Management)**: Authentication, SSO, Federation (SAML/OAuth/OIDC)
- **PingIDM (ForgeRock Identity Management)**: Identity lifecycle and provisioning
- **PingGateway (ForgeRock Identity Gateway)**: Reverse proxy and policy enforcement

### Architecture Overview

```
                                    ┌─────────────────┐
                                    │  ServiceNow     │
                                    │  Instance       │
                                    └────────┬────────┘
                                             │
                                    ┌────────▼────────┐
                      ┌─────────────┤  PingGateway    ├─────────────┐
                      │             │  :8083/:8446    │             │
                      │             └─────────────────┘             │
                      │                                             │
         ┌────────────▼────────────┐              ┌────────────────▼─────────┐
         │      PingAM             │              │      PingIDM             │
         │  (Access Management)    │◄────────────►│ (Identity Management)   │
         │    :8081/:8444          │              │    :8082/:8445           │
         └────────────┬────────────┘              └──────────────────────────┘
                      │                                      │
                      │              ┌───────────────────────┘
                      │              │
                ┌─────▼──────────────▼─────┐
                │       PingDS             │
                │  (Directory Services)    │
                │    :1389/:1636           │
                └──────────────────────────┘
                      │
         ┌────────────┴────────────┐
         │                         │
    ┌────▼────┐              ┌─────▼────┐
    │  AD DC  │              │  AD DC   │
    │  .1.2   │              │  .1.3    │
    └─────────┘              └──────────┘
```

---

## Prerequisites

### Software Requirements

1. **Windows Server 2019** with latest updates
2. **Docker Desktop for Windows** (version 4.x or higher)
   - Download: https://www.docker.com/products/docker-desktop
3. **PowerShell 5.1** or higher (included with Windows Server 2019)
4. **Git for Windows** (optional, for version control)

### Hardware Requirements (Minimum for Testing)

- **CPU**: 8 cores (16 recommended)
- **RAM**: 16 GB (32 GB recommended)
- **Disk**: 200 GB free space (SSD recommended)
- **Network**: 1 Gbps network adapter

### Network Requirements

- Access to domain controllers: `192.168.1.2` and `192.168.1.3`
- Ports available: 1389, 1636, 4444, 8080-8083, 8443-8446
- DNS resolution for `*.devnetwork.dev` domain

### Active Directory Requirements

#### Service Account Creation

Create a service account in Active Directory for ForgeRock to query AD:

1. Open **Active Directory Users and Computers**
2. Navigate to **Users** container
3. Right-click → **New** → **User**
4. Create user with these properties:
   - **Username**: `svc-forgerock`
   - **Full name**: `ForgeRock Service Account`
   - **Password**: Use strong password (15+ characters, complexity requirements)
   - **Password never expires**: ☑ (Check)
   - **User cannot change password**: ☑ (Check)

5. Grant necessary permissions:
   ```powershell
   # Run in PowerShell on Domain Controller
   Import-Module ActiveDirectory

   # Grant read permissions to the service account
   $ServiceAccount = "svc-forgerock"
   $Domain = "devnetwork.dev"
   $DomainDN = "DC=devnetwork,DC=dev"

   # Add to Domain Users (default)
   # For enhanced security, create custom group with limited read permissions
   ```

#### Required Group Memberships

- **Minimum**: Domain Users
- **Recommended**: Create custom group `ForgeRock_LDAP_Readers` with delegated read permissions

---

## Initial Setup - Windows Server 2019

### Step 1: Install Docker Desktop

1. Download Docker Desktop for Windows:
   ```powershell
   # Download using PowerShell (if internet access available)
   Invoke-WebRequest -Uri "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" -OutFile "$env:USERPROFILE\Downloads\DockerDesktopInstaller.exe"
   ```

2. Run the installer:
   ```powershell
   Start-Process -FilePath "$env:USERPROFILE\Downloads\DockerDesktopInstaller.exe" -Wait
   ```

3. **Restart the server** after installation

4. Verify Docker installation:
   ```powershell
   docker --version
   docker-compose --version
   ```

   Expected output:
   ```
   Docker version 24.x.x, build xxxxxxx
   Docker Compose version v2.x.x
   ```

### Step 2: Configure Docker Desktop

1. Open Docker Desktop from Start Menu
2. Navigate to **Settings** → **Resources** → **Advanced**
3. Configure resources:
   - **CPUs**: 6-8 (leave 2 for Windows)
   - **Memory**: 12 GB (leave 4 GB for Windows)
   - **Disk image size**: 100 GB
4. Click **Apply & Restart**

### Step 3: Configure Windows Firewall

```powershell
# Open PowerShell as Administrator

# Allow ForgeRock service ports
$ports = @(1389, 1636, 4444, 8080, 8081, 8082, 8083, 8443, 8444, 8445, 8446)

foreach ($port in $ports) {
    New-NetFirewallRule -DisplayName "ForgeRock Port $port" `
                        -Direction Inbound `
                        -LocalPort $port `
                        -Protocol TCP `
                        -Action Allow
}

Write-Host "Firewall rules created successfully" -ForegroundColor Green
```

### Step 4: Configure DNS (Optional but Recommended)

Add local DNS entries for ForgeRock services:

```powershell
# Open PowerShell as Administrator

$hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
$entries = @"

# ForgeRock Identity Platform - devnetwork.dev
127.0.0.1    pingds.devnetwork.dev
127.0.0.1    pingam.devnetwork.dev
127.0.0.1    pingidm.devnetwork.dev
127.0.0.1    pinggateway.devnetwork.dev
"@

Add-Content -Path $hostsFile -Value $entries
Write-Host "Hosts file updated" -ForegroundColor Green
```

---

## Private Docker Registry Setup (Air-Gapped)

For air-gapped environments, you'll need a private Docker registry to host ForgeRock images.

### Setting Up Private Registry

#### Method 1: Using Docker Registry Container

1. Create registry directories:
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Documents\DockerRegistry\data"
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Documents\DockerRegistry\certs"
   ```

2. Generate self-signed certificate (for testing):
   ```powershell
   # Install OpenSSL for Windows first, or use existing certificate

   # Using PowerShell to create certificate
   $cert = New-SelfSignedCertificate -DnsName "registry.devnetwork.dev" `
                                      -CertStoreLocation "cert:\LocalMachine\My" `
                                      -KeyExportPolicy Exportable

   # Export certificate
   $certPath = "$env:USERPROFILE\Documents\DockerRegistry\certs"
   $pwd = ConvertTo-SecureString -String "YourCertPassword" -Force -AsPlainText

   Export-PfxCertificate -Cert $cert -FilePath "$certPath\registry.pfx" -Password $pwd

   # Convert to PEM format (requires OpenSSL)
   # openssl pkcs12 -in registry.pfx -out registry.crt -nokeys
   # openssl pkcs12 -in registry.pfx -out registry.key -nodes -nocerts
   ```

3. Create registry Docker Compose file:
   ```yaml
   # Save as docker-registry.yml
   version: '3.8'

   services:
     registry:
       image: registry:2
       container_name: docker-registry
       ports:
         - "5000:5000"
       volumes:
         - C:\Users\<username>\Documents\DockerRegistry\data:/var/lib/registry
         - C:\Users\<username>\Documents\DockerRegistry\certs:/certs
       environment:
         - REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt
         - REGISTRY_HTTP_TLS_KEY=/certs/registry.key
       restart: always
   ```

4. Start the registry:
   ```powershell
   docker-compose -f docker-registry.yml up -d
   ```

### Pulling and Pushing Images to Private Registry

#### Step 1: Pull ForgeRock Images (On Internet-Connected Machine)

```powershell
# Authenticate to ForgeRock registry (requires ForgeRock account)
docker login gcr.io/forgerock-io

# Pull ForgeRock 8.0 images
$images = @(
    "gcr.io/forgerock-io/ds/pit1:8.0.0",
    "gcr.io/forgerock-io/am/pit1:8.0.0",
    "gcr.io/forgerock-io/idm/pit1:8.0.0",
    "gcr.io/forgerock-io/ig/pit1:8.0.0"
)

foreach ($image in $images) {
    Write-Host "Pulling $image..." -ForegroundColor Cyan
    docker pull $image
}
```

#### Step 2: Save Images to TAR Files (For Air-Gapped Transfer)

```powershell
# Create export directory
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Documents\ForgeRockImages"

# Save each image
docker save gcr.io/forgerock-io/ds/pit1:8.0.0 -o "$env:USERPROFILE\Documents\ForgeRockImages\pingds-8.0.0.tar"
docker save gcr.io/forgerock-io/am/pit1:8.0.0 -o "$env:USERPROFILE\Documents\ForgeRockImages\pingam-8.0.0.tar"
docker save gcr.io/forgerock-io/idm/pit1:8.0.0 -o "$env:USERPROFILE\Documents\ForgeRockImages\pingidm-8.0.0.tar"
docker save gcr.io/forgerock-io/ig/pit1:8.0.0 -o "$env:USERPROFILE\Documents\ForgeRockImages\pinggateway-8.0.0.tar"

Write-Host "Images exported successfully" -ForegroundColor Green
Write-Host "Transfer the 'ForgeRockImages' folder to your air-gapped environment"
```

#### Step 3: Load Images in Air-Gapped Environment

```powershell
# In air-gapped environment, load the TAR files
$tarFiles = Get-ChildItem -Path "$env:USERPROFILE\Documents\ForgeRockImages\*.tar"

foreach ($tarFile in $tarFiles) {
    Write-Host "Loading $($tarFile.Name)..." -ForegroundColor Cyan
    docker load -i $tarFile.FullName
}

Write-Host "All images loaded successfully" -ForegroundColor Green
```

#### Step 4: Tag and Push to Private Registry (Optional)

If using private registry in air-gapped environment:

```powershell
# Tag images for private registry
docker tag gcr.io/forgerock-io/ds/pit1:8.0.0 registry.devnetwork.dev:5000/pingds:8.0.0
docker tag gcr.io/forgerock-io/am/pit1:8.0.0 registry.devnetwork.dev:5000/pingam:8.0.0
docker tag gcr.io/forgerock-io/idm/pit1:8.0.0 registry.devnetwork.dev:5000/pingidm:8.0.0
docker tag gcr.io/forgerock-io/ig/pit1:8.0.0 registry.devnetwork.dev:5000/pinggateway:8.0.0

# Push to private registry
docker push registry.devnetwork.dev:5000/pingds:8.0.0
docker push registry.devnetwork.dev:5000/pingam:8.0.0
docker push registry.devnetwork.dev:5000/pingidm:8.0.0
docker push registry.devnetwork.dev:5000/pinggateway:8.0.0
```

**Note**: If using private registry, update `docker-compose.yml` image references:
```yaml
# Change from:
image: gcr.io/forgerock-io/ds/pit1:8.0.0

# To:
image: registry.devnetwork.dev:5000/pingds:8.0.0
```

---

## Directory Structure Creation

### Step 1: Create Base Directory Structure

```powershell
# Run in PowerShell

$basePath = "$env:USERPROFILE\Documents\PingData"

# Create main directories
$directories = @(
    "$basePath\ds",
    "$basePath\am",
    "$basePath\idm",
    "$basePath\gateway",
    "$basePath\..\PingBackups",
    "$basePath\..\ping\config\ds",
    "$basePath\..\ping\config\am",
    "$basePath\..\ping\config\idm",
    "$basePath\..\ping\config\gateway",
    "$basePath\..\ping\scripts\ds",
    "$basePath\..\ping\scripts\am",
    "$basePath\..\ping\scripts\idm",
    "$basePath\..\ping\scripts\gateway",
    "$basePath\..\ping\secrets"
)

foreach ($dir in $directories) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

Write-Host "Directory structure created at: $basePath" -ForegroundColor Green
```

### Step 2: Verify Directory Structure

```powershell
# Verify structure
tree "$env:USERPROFILE\Documents" /F
```

Expected structure:
```
Documents
├── PingData
│   ├── ds
│   ├── am
│   ├── idm
│   └── gateway
├── PingBackups
└── ping (your project directory)
    ├── config
    │   ├── ds
    │   ├── am
    │   ├── idm
    │   └── gateway
    ├── scripts
    │   ├── ds
    │   ├── am
    │   ├── idm
    │   └── gateway
    └── secrets
```

---

## Configuration

### Step 1: Configure Environment Variables

1. Navigate to your project directory:
   ```powershell
   cd $env:USERPROFILE\Documents\ping
   ```

2. Edit the `.env` file with your specific values:
   ```powershell
   notepad .env
   ```

3. **CRITICAL**: Update these values:

   ```ini
   # Generate secure deployment key
   DEPLOYMENT_KEY=<generate with: openssl rand -base64 32>

   # Update all passwords (minimum 15 characters)
   DS_PASSWORD=YourSecurePassword123!@#
   AM_ADMIN_PASSWORD=YourSecurePassword123!@#
   IDM_ADMIN_PASSWORD=YourSecurePassword123!@#
   KEYSTORE_PASSWORD=YourSecurePassword123!@#

   # Active Directory service account
   AD_BIND_DN=CN=svc-forgerock,CN=Users,DC=devnetwork,DC=dev
   AD_BIND_PASSWORD=YourADServiceAccountPassword

   # ServiceNow instance
   SNOW_INSTANCE_URL=https://your-actual-instance.service-now.com
   ```

### Step 2: Generate Deployment Key

```powershell
# Using PowerShell to generate secure key
$bytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$deploymentKey = [Convert]::ToBase64String($bytes)

Write-Host "Generated Deployment Key:" -ForegroundColor Cyan
Write-Host $deploymentKey -ForegroundColor Yellow
Write-Host "`nAdd this to your .env file as DEPLOYMENT_KEY" -ForegroundColor Green
```

### Step 3: Create Secrets Files

```powershell
# Create secrets directory and files
$secretsPath = ".\secrets"

# DS admin password
$dsPassword = Read-Host "Enter DS Directory Manager Password" -AsSecureString
$dsPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($dsPassword))
$dsPasswordText | Out-File -FilePath "$secretsPath\ds-admin-password.txt" -NoNewline

# AM admin password
$amPassword = Read-Host "Enter AM Admin Password" -AsSecureString
$amPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($amPassword))
$amPasswordText | Out-File -FilePath "$secretsPath\am-admin-password.txt" -NoNewline

Write-Host "Secrets created successfully" -ForegroundColor Green
```

---

## Deployment Steps

### Step 1: Pre-Deployment Validation

```powershell
# Validate Docker is running
docker info

# Validate docker-compose.yml syntax
docker-compose config

# Check available resources
docker system info

# Verify .env file exists
Test-Path .\.env
```

### Step 2: Pull/Load Images

**Option A: Internet-Connected Environment**
```powershell
# Pull images directly
docker-compose pull
```

**Option B: Air-Gapped Environment**
```powershell
# Images should already be loaded (see Private Registry section)
# Verify images are available
docker images | Select-String "forgerock"
```

### Step 3: Start the Stack

```powershell
# Start all services in detached mode
docker-compose up -d

# Monitor startup logs
docker-compose logs -f
```

**Expected startup order:**
1. PingDS starts first (120-180 seconds)
2. PingAM starts after DS is healthy (180-240 seconds)
3. PingIDM starts after AM is healthy (120-180 seconds)
4. PingGateway starts after AM is healthy (90-120 seconds)

**Total expected startup time: 10-15 minutes**

### Step 4: Monitor Service Health

```powershell
# Check service status
docker-compose ps

# Check individual service health
docker-compose logs pingds | Select-String "ready"
docker-compose logs pingam | Select-String "Server startup"
docker-compose logs pingidm | Select-String "OpenIDM ready"
docker-compose logs pinggateway | Select-String "Started"
```

### Step 5: Verify Services are Running

```powershell
# Test each service endpoint
Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing  # PingDS HTTP
Invoke-WebRequest -Uri "http://localhost:8081/am/console" -UseBasicParsing  # PingAM
Invoke-WebRequest -Uri "http://localhost:8082/openidm/info/ping" -UseBasicParsing  # PingIDM
Invoke-WebRequest -Uri "http://localhost:8083/health" -UseBasicParsing  # PingGateway
```

---

## Active Directory Integration

### Overview

Integrating ForgeRock with Active Directory enables:
- User authentication against AD
- Identity synchronization
- Group membership management
- Password policies from AD

### Step 1: Configure PingDS for AD Proxy

Create AD proxy configuration in PingDS:

```bash
# Access PingDS container
docker exec -it pingds.devnetwork.dev /bin/bash

# Create AD data source
/opt/opendj/bin/dsconfig create-external-server \
  --hostname localhost \
  --port 4444 \
  --bindDN "cn=Directory Manager" \
  --bindPassword "password" \
  --server-name "AD-DC1" \
  --type ldap \
  --set server-host-name:192.168.1.2 \
  --set server-port:389 \
  --trustAll \
  --no-prompt

/opt/opendj/bin/dsconfig create-external-server \
  --hostname localhost \
  --port 4444 \
  --bindDN "cn=Directory Manager" \
  --bindPassword "password" \
  --server-name "AD-DC2" \
  --type ldap \
  --set server-host-name:192.168.1.3 \
  --set server-port:389 \
  --trustAll \
  --no-prompt
```

### Step 2: Configure PingAM Data Store for AD

1. Access PingAM Console:
   ```
   URL: http://localhost:8081/am/console
   Username: amadmin
   Password: <AM_ADMIN_PASSWORD from .env>
   ```

2. Navigate to: **Realms** → **Top Level Realm** → **Data Stores**

3. Click **Add Data Store**:
   - **Name**: `ActiveDirectory`
   - **Type**: Active Directory

4. Configure connection:
   ```
   LDAP Server: 192.168.1.2:389
   LDAP Bind DN: CN=svc-forgerock,CN=Users,DC=devnetwork,DC=dev
   LDAP Bind Password: <AD_BIND_PASSWORD>
   LDAP Search Base DN: DC=devnetwork,DC=dev
   ```

5. Configure failover:
   - Click **Add** next to LDAP Servers
   - Add: `192.168.1.3:389`

6. Test connection:
   - Click **Test Connection**
   - Should see: "Connection successful"

7. Save configuration

### Step 3: Configure Authentication Chain for AD

1. Navigate to: **Realms** → **Top Level Realm** → **Authentication** → **Modules**

2. Create new module:
   - **Name**: `AD-LDAP`
   - **Type**: LDAP
   - **Primary LDAP Server**: `192.168.1.2:389`
   - **Secondary LDAP Server**: `192.168.1.3:389`
   - **DN to Start User Search**: `DC=devnetwork,DC=dev`
   - **Bind User DN**: `CN=svc-forgerock,CN=Users,DC=devnetwork,DC=dev`
   - **Bind User Password**: `<AD_BIND_PASSWORD>`
   - **Attribute Used to Retrieve User Profile**: `sAMAccountName`
   - **User Search Attributes**: `sAMAccountName`
   - **User Search Filter**: `(objectClass=user)`
   - **LDAP Connection Mode**: `LDAP`
   - **Return User DN to DataStore**: `Enabled`

3. Create authentication chain:
   - Navigate to: **Authentication** → **Chains**
   - Click **Add Chain**
   - **Name**: `ADAuthChain`
   - Add module: `AD-LDAP` with criteria `REQUIRED`

4. Set as default:
   - Navigate to: **Authentication** → **Settings** → **Core**
   - Set **Organization Authentication Configuration**: `ADAuthChain`

### Step 4: Test AD Authentication

```powershell
# Test AD authentication via REST API
$username = "testuser"  # AD username
$password = "UserPassword123!"  # AD user password
$amUrl = "http://localhost:8081/am"

# Get authentication token
$body = @{
    authIndexType = "service"
    authIndexValue = "ADAuthChain"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "$amUrl/json/authenticate" `
                               -Method POST `
                               -Body $body `
                               -ContentType "application/json" `
                               -Headers @{"X-OpenAM-Username"=$username; "X-OpenAM-Password"=$password}

Write-Host "Token: $($response.tokenId)" -ForegroundColor Green
```

### Step 5: Configure PingIDM for AD Synchronization

1. Access PingIDM Admin UI:
   ```
   URL: http://localhost:8082/admin
   Username: openidm-admin
   Password: <IDM_ADMIN_PASSWORD>
   ```

2. Navigate to: **Configure** → **Connectors**

3. Create AD Connector:
   - Click **New Connector**
   - **Connector Type**: LDAP Connector
   - **Connector Name**: `ADConnector`

4. Configure connection:
   ```json
   {
     "host": "192.168.1.2",
     "port": 389,
     "ssl": false,
     "principal": "CN=svc-forgerock,CN=Users,DC=devnetwork,DC=dev",
     "credentials": "<AD_BIND_PASSWORD>",
     "baseContexts": [
       "DC=devnetwork,DC=dev"
     ],
     "accountObjectClasses": [
       "user"
     ],
     "groupObjectClasses": [
       "group"
     ],
     "accountSearchFilter": "(&(objectClass=user)(!(objectClass=computer)))",
     "groupSearchFilter": "(objectClass=group)"
   }
   ```

5. Configure failover:
   - Add secondary server: `192.168.1.3:389`
   - Enable connection pooling
   - Set timeout: 30 seconds

6. Test connector:
   - Click **Test Connector Configuration**
   - Should see successful connection

7. Create mapping:
   - Navigate to: **Configure** → **Mappings**
   - Create mapping: `systemLdapAccount_managedUser`
   - Map attributes:
     ```
     AD Attribute          →  IDM Attribute
     sAMAccountName        →  userName
     givenName             →  givenName
     sn                    →  sn
     mail                  →  mail
     telephoneNumber       →  telephoneNumber
     memberOf              →  groups
     ```

8. Enable synchronization:
   - Navigate to: **Configure** → **Schedules**
   - Create schedule: `AD Sync`
   - Schedule: Every 5 minutes
   - Trigger: `reconcile`
   - Mapping: `systemLdapAccount_managedUser`

### Step 6: Verify AD Integration

```powershell
# Query IDM for synchronized users
$idmUrl = "http://localhost:8082/openidm"
$idmUser = "openidm-admin"
$idmPass = "<IDM_ADMIN_PASSWORD>"

$secpass = ConvertTo-SecureString $idmPass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($idmUser, $secpass)

$users = Invoke-RestMethod -Uri "$idmUrl/managed/user?_queryFilter=true" `
                           -Method GET `
                           -Credential $credential

Write-Host "Synchronized users from AD:" -ForegroundColor Cyan
$users.result | Format-Table userName, givenName, sn, mail
```

---

## ServiceNow Integration

### Overview

Integrate ForgeRock with ServiceNow for Single Sign-On using both SAML 2.0 and OAuth/OIDC.

### SAML 2.0 Integration

#### Step 1: Export PingAM SAML Metadata

1. Access PingAM Console: `http://localhost:8081/am/console`

2. Navigate to: **Realms** → **Top Level Realm** → **Applications** → **Federation** → **Entity Providers**

3. Create Hosted Identity Provider:
   - Click **Create Hosted Identity Provider**
   - **Name**: `ForgeRockIDP`
   - **Circle of Trust**: Create new → `ServiceNowCoT`
   - Click **Configure**

4. Export metadata:
   - Click on the created IDP
   - Click **Export Metadata**
   - Save as: `forgerock-idp-metadata.xml`

   Example metadata:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <EntityDescriptor entityID="http://pingam.devnetwork.dev:8081/am"
                     xmlns="urn:oasis:names:tc:SAML:2.0:metadata">
     <IDPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
       <KeyDescriptor use="signing">
         <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
           <ds:X509Data>
             <ds:X509Certificate>...</ds:X509Certificate>
           </ds:X509Data>
         </ds:KeyInfo>
       </KeyDescriptor>
       <SingleSignOnService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                           Location="http://pingam.devnetwork.dev:8081/am/SSORedirect/metaAlias/idp"/>
     </IDPSSODescriptor>
   </EntityDescriptor>
   ```

#### Step 2: Configure ServiceNow as Service Provider

1. Log into ServiceNow instance as admin

2. Navigate to: **System Security** → **Single Sign-On** → **Multi-Provider SSO** → **Identity Providers**

3. Click **New**:
   - **Name**: `ForgeRock SAML IDP`
   - **Import Identity Provider Metadata**: Upload `forgerock-idp-metadata.xml`

4. Configure provider:
   ```
   Default: ☑ (if this is the default authentication method)
   Active: ☑

   Identity Provider's SingleSignOn URL:
     http://pingam.devnetwork.dev:8081/am/SSORedirect/metaAlias/idp

   Identity Provider's SingleLogOut URL:
     http://pingam.devnetwork.dev:8081/am/IDPSloRedirect/metaAlias/idp

   NameID Policy: urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified

   User Field: Email
   ```

5. Save and export ServiceNow metadata:
   - Click **Export SP Metadata**
   - Save as: `servicenow-sp-metadata.xml`

#### Step 3: Import ServiceNow SP Metadata to PingAM

1. Back in PingAM Console

2. Navigate to: **Federation** → **Entity Providers**

3. Click **Import Entity...**:
   - Upload `servicenow-sp-metadata.xml`
   - **Circle of Trust**: `ServiceNowCoT`
   - Click **Configure**

4. Configure attribute mapping:
   - Navigate to the imported SP
   - Click **Assertion Processing** → **Attribute Mapper**
   - Map attributes:
     ```
     ForgeRock Attribute  →  SAML Attribute Name
     mail                 →  email
     cn                   →  name
     sAMAccountName       →  username
     givenName            →  first_name
     sn                   →  last_name
     ```

#### Step 4: Test SAML SSO

1. In ServiceNow, navigate to: `https://your-instance.service-now.com/login.do`

2. Click **SSO with ForgeRock SAML IDP**

3. Should redirect to PingAM login: `http://pingam.devnetwork.dev:8081/am/XUI/#login`

4. Enter AD credentials

5. Should redirect back to ServiceNow and be authenticated

**Testing from PowerShell:**
```powershell
# Initiate SAML authentication flow
$snowInstance = "https://your-instance.service-now.com"
$samlEndpoint = "$snowInstance/navpage.do"

# This will open browser for SSO flow
Start-Process $samlEndpoint
```

### OAuth 2.0 / OIDC Integration

#### Step 1: Create OAuth2 Provider in PingAM

1. Access PingAM Console

2. Navigate to: **Realms** → **Top Level Realm** → **Services**

3. Add **OAuth2 Provider** service:
   - Click **Add a Service**
   - Select **OAuth2 Provider**
   - Use default settings (can customize later)
   - Click **Create**

4. Configure OAuth2 Provider:
   ```
   Authorization Code Lifetime: 10 minutes
   Access Token Lifetime: 60 minutes
   Refresh Token Lifetime: 43200 minutes (30 days)
   Issue Refresh Tokens: ☑

   Supported Scopes:
     - openid
     - profile
     - email
     - address
     - phone

   OIDC Claims Script: default
   ```

5. Save configuration

#### Step 2: Register ServiceNow as OAuth2 Client

1. Navigate to: **Realms** → **Top Level Realm** → **Applications** → **OAuth 2.0**

2. Click **Add Client**:
   ```
   Client ID: servicenow-client
   Client Secret: <generate strong secret - min 32 characters>

   Redirection URIs:
     https://your-instance.service-now.com/oauth_redirect.do

   Scope(s):
     openid profile email

   Default Scope(s):
     openid profile email

   Client Type: Confidential

   Grant Types:
     ☑ Authorization Code
     ☑ Refresh Token

   Response Types:
     ☑ code
     ☑ token
     ☑ id_token

   Token Endpoint Authentication Method:
     client_secret_post

   ID Token Signing Algorithm: RS256
   ```

3. Save client configuration

4. **Important**: Copy the Client ID and Client Secret for ServiceNow configuration

#### Step 3: Configure ServiceNow OAuth Provider

1. In ServiceNow, navigate to: **System OAuth** → **Application Registry**

2. Click **New** → **Connect to a third party OAuth Provider**:
   ```
   Name: ForgeRock OAuth Provider
   Client ID: servicenow-client
   Client Secret: <from PingAM>

   Default Grant Type: Authorization Code

   Authorization URL:
     http://pingam.devnetwork.dev:8081/am/oauth2/authorize

   Token URL:
     http://pingam.devnetwork.dev:8081/am/oauth2/access_token

   Token Revocation URL:
     http://pingam.devnetwork.dev:8081/am/oauth2/token/revoke

   Redirect URL:
     https://your-instance.service-now.com/oauth_redirect.do

   Send Credentials: As Basic Authorization Header

   OAuth Entity Scopes:
     openid profile email
   ```

3. Save configuration

#### Step 4: Create ServiceNow OAuth2 Entity

1. Navigate to: **System Security** → **Single Sign-On** → **Multi-Provider SSO** → **Identity Providers**

2. Click **New**:
   ```
   Name: ForgeRock OAuth2 Provider
   Type: OpenID Connect
   Active: ☑

   OAuth Entity: ForgeRock OAuth Provider (from step 3)

   User Claim: email or sub
   User Field: Email

   Authorize URL:
     http://pingam.devnetwork.dev:8081/am/oauth2/authorize

   Token URL:
     http://pingam.devnetwork.dev:8081/am/oauth2/access_token

   UserInfo URL:
     http://pingam.devnetwork.dev:8081/am/oauth2/userinfo

   Logout URL:
     http://pingam.devnetwork.dev:8081/am/oauth2/connect/endSession

   JWKS URL:
     http://pingam.devnetwork.dev:8081/am/oauth2/connect/jwk_uri
   ```

3. Save configuration

#### Step 5: Test OAuth/OIDC Integration

**Test Authentication Flow:**

```powershell
# Step 1: Get authorization code
$clientId = "servicenow-client"
$redirectUri = "https://your-instance.service-now.com/oauth_redirect.do"
$scope = "openid profile email"
$amUrl = "http://pingam.devnetwork.dev:8081/am"

$authUrl = "$amUrl/oauth2/authorize?response_type=code&client_id=$clientId&redirect_uri=$redirectUri&scope=$scope"

Write-Host "Open this URL in browser:" -ForegroundColor Cyan
Write-Host $authUrl -ForegroundColor Yellow

# User will authenticate and be redirected with code parameter
# Example: https://your-instance.service-now.com/oauth_redirect.do?code=ABC123...

# Step 2: Exchange code for token (manual example)
$code = Read-Host "Enter the authorization code from redirect"
$clientSecret = Read-Host "Enter client secret" -AsSecureString
$clientSecretText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientSecret))

$tokenBody = @{
    grant_type = "authorization_code"
    code = $code
    redirect_uri = $redirectUri
    client_id = $clientId
    client_secret = $clientSecretText
}

$tokenResponse = Invoke-RestMethod -Uri "$amUrl/oauth2/access_token" `
                                    -Method POST `
                                    -Body $tokenBody `
                                    -ContentType "application/x-www-form-urlencoded"

Write-Host "Access Token:" -ForegroundColor Green
Write-Host $tokenResponse.access_token

Write-Host "`nID Token:" -ForegroundColor Green
Write-Host $tokenResponse.id_token

# Step 3: Get user info
$userInfo = Invoke-RestMethod -Uri "$amUrl/oauth2/userinfo" `
                               -Method GET `
                               -Headers @{Authorization = "Bearer $($tokenResponse.access_token)"}

Write-Host "`nUser Info:" -ForegroundColor Green
$userInfo | ConvertTo-Json
```

---

## DoD Zero Trust Hardening

### Overview

Implement DoD Zero Trust Reference Architecture security controls.

### Step 1: TLS/SSL Configuration

#### Generate Proper Certificates

```powershell
# Install OpenSSL for Windows if not already installed
# Download from: https://slproweb.com/products/Win32OpenSSL.html

# Create certificate directory
New-Item -ItemType Directory -Force -Path ".\certs"

# Generate CA certificate
& "C:\Program Files\OpenSSL-Win64\bin\openssl.exe" req -x509 -newkey rsa:4096 `
    -keyout ".\certs\ca-key.pem" `
    -out ".\certs\ca-cert.pem" `
    -days 3650 -nodes `
    -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=ForgeRock-CA"

# Generate server certificates for each service
$services = @("pingds", "pingam", "pingidm", "pinggateway")

foreach ($service in $services) {
    $fqdn = "$service.devnetwork.dev"

    # Generate private key
    & openssl genrsa -out ".\certs\$service-key.pem" 4096

    # Generate CSR
    & openssl req -new `
        -key ".\certs\$service-key.pem" `
        -out ".\certs\$service.csr" `
        -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=$fqdn"

    # Sign with CA
    & openssl x509 -req `
        -in ".\certs\$service.csr" `
        -CA ".\certs\ca-cert.pem" `
        -CAkey ".\certs\ca-key.pem" `
        -CAcreateserial `
        -out ".\certs\$service-cert.pem" `
        -days 825 `
        -sha256

    Write-Host "Certificate created for $fqdn" -ForegroundColor Green
}
```

#### Configure TLS in ForgeRock Services

Create custom configuration file: `config/am/tls-config.json`
```json
{
  "tlsProtocols": ["TLSv1.2", "TLSv1.3"],
  "tlsCipherSuites": [
    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
  ],
  "enableSNI": true,
  "enableOCSP": true
}
```

### Step 2: Enable Audit Logging (DoD Compliance)

#### Configure Comprehensive Audit Logging

Create audit configuration: `config/am/audit-config.json`
```json
{
  "auditServiceConfig": {
    "handlerForQueries": "json",
    "availableAuditEventHandlers": [
      "org.forgerock.audit.handlers.json.JsonAuditEventHandler",
      "org.forgerock.audit.handlers.csv.CsvAuditEventHandler",
      "org.forgerock.audit.handlers.syslog.SyslogAuditEventHandler"
    ],
    "filterPolicies": {
      "field": {
        "excludeIf": [],
        "includeIf": []
      }
    }
  },
  "eventHandlers": [
    {
      "class": "org.forgerock.audit.handlers.json.JsonAuditEventHandler",
      "config": {
        "name": "json",
        "topics": [
          "access",
          "activity",
          "authentication",
          "config"
        ],
        "logDirectory": "/opt/am/data/audit",
        "rotationEnabled": true,
        "rotationFilePrefix": "audit-",
        "rotationFileSuffix": ".log",
        "rotationInterval": "1 day",
        "rotationTimes": ["00:00"],
        "retentionPolicy": {
          "maxNumberOfHistoryFiles": 365,
          "minFreeSpaceRequired": "1 GB"
        },
        "buffering": {
          "enabled": true,
          "maxSize": 10000
        }
      }
    },
    {
      "class": "org.forgerock.audit.handlers.syslog.SyslogAuditEventHandler",
      "config": {
        "name": "syslog",
        "topics": [
          "access",
          "authentication"
        ],
        "protocol": "TCP",
        "host": "syslog-server.devnetwork.dev",
        "port": 514,
        "facility": "LOCAL0",
        "severityFieldMappings": [
          {
            "topic": "authentication",
            "field": "result",
            "valueMappings": {
              "SUCCESSFUL": "INFORMATIONAL",
              "FAILED": "ERROR"
            }
          }
        ]
      }
    }
  ],
  "eventTopics": {
    "access": {
      "events": ["AM-ACCESS-ATTEMPT", "AM-ACCESS-OUTCOME"]
    },
    "activity": {
      "events": ["AM-SESSION-CREATED", "AM-SESSION-IDLE", "AM-SESSION-MAX", "AM-SESSION-LOGOUT"]
    },
    "authentication": {
      "events": ["AM-AUTHENTICATION-SUCCESS", "AM-AUTHENTICATION-FAILED"]
    },
    "config": {
      "events": ["AM-CONFIG-CHANGE"]
    }
  }
}
```

#### Enable Audit in Docker Compose

Update `docker-compose.yml` to mount audit config:
```yaml
services:
  pingam:
    volumes:
      - ./config/am/audit-config.json:/opt/am/config/services/audit/config.json:ro
```

### Step 3: Implement Multi-Factor Authentication (MFA)

#### Configure TOTP (Time-based One-Time Password)

1. Access PingAM Console

2. Navigate to: **Realms** → **Top Level Realm** → **Authentication** → **Modules**

3. Create OATH module:
   - Click **Add Module**
   - **Name**: `TOTP-MFA`
   - **Type**: OATH
   - Configuration:
     ```
     OATH Algorithm: TOTP
     TOTP Time Step: 30 seconds
     TOTP Time Steps: 2
     One Time Password Length: 6
     Minimum Secret Key Length: 32
     ```

4. Create MFA authentication chain:
   - Navigate to: **Authentication** → **Chains**
   - Create chain: `MFA-Chain`
   - Modules:
     1. `AD-LDAP` - REQUIRED
     2. `TOTP-MFA` - REQUIRED

5. Apply to high-privilege users:
   - Navigate to: **Realms** → **Top Level Realm** → **Authentication** → **Settings**
   - Set for admin realm: `MFA-Chain`

### Step 4: Configure Session Management (DoD Requirements)

#### Strict Session Timeouts

Create session configuration: `config/am/session-config.json`
```json
{
  "sessionProperties": {
    "maxSessionTime": "30",
    "maxIdleTime": "30",
    "maxCachingTime": "3",
    "sessionQuota": {
      "enabled": true,
      "limit": 3,
      "exhaustionAction": "DENY_ACCESS"
    },
    "enableSessionConstraints": true,
    "sessionConstraints": [
      {
        "constraint": "DEVICE_FINGERPRINT",
        "enabled": true
      },
      {
        "constraint": "IP_ADDRESS",
        "enabled": true
      }
    ]
  },
  "security": {
    "httpOnlyCookie": true,
    "secureCookie": true,
    "sameSite": "Strict",
    "cookieEncryption": true
  }
}
```

### Step 5: Enable Advanced Threat Protection

#### Configure Anomaly Detection

Create threat protection config: `config/am/threat-protection.json`
```json
{
  "threatProtection": {
    "bruteForceProtection": {
      "enabled": true,
      "failedLoginLockout": {
        "threshold": 3,
        "duration": "30 minutes",
        "incrementalLockout": true
      },
      "ipBlacklisting": {
        "enabled": true,
        "threshold": 10,
        "duration": "1 hour"
      }
    },
    "deviceFingerprinting": {
      "enabled": true,
      "attributes": [
        "USER_AGENT",
        "SCREEN_RESOLUTION",
        "TIMEZONE",
        "LANGUAGE",
        "PLUGINS"
      ]
    },
    "riskBasedAuthentication": {
      "enabled": true,
      "riskScoreThresholds": {
        "low": 30,
        "medium": 60,
        "high": 80
      },
      "riskFactors": [
        {
          "factor": "IMPOSSIBLE_TRAVEL",
          "weight": 50
        },
        {
          "factor": "NEW_DEVICE",
          "weight": 30
        },
        {
          "factor": "UNUSUAL_TIME",
          "weight": 20
        }
      ]
    }
  }
}
```

### Step 6: Network Segmentation

#### Configure PingGateway for Policy Enforcement

Create gateway routes: `config/gateway/routes/servicenow-route.json`
```json
{
  "name": "ServiceNow Protected Route",
  "baseURI": "https://your-instance.service-now.com",
  "condition": "${matches(request.uri.path, '^/api/.*')}",
  "heap": [
    {
      "name": "AmService",
      "type": "AmService",
      "config": {
        "url": "http://pingam.devnetwork.dev:8081/am",
        "realm": "/",
        "version": "7.0",
        "agent": {
          "username": "gateway-agent",
          "passwordSecretId": "agent.secret.id"
        },
        "sessionCache": {
          "enabled": true,
          "executor": "ScheduledExecutorService"
        }
      }
    }
  ],
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [
        {
          "name": "OAuth2ResourceServerFilter",
          "type": "OAuth2ResourceServerFilter",
          "config": {
            "scopes": ["openid", "profile"],
            "requireHttps": true,
            "realm": "ForgeRock",
            "accessTokenResolver": {
              "name": "token-resolver",
              "type": "TokenIntrospectionAccessTokenResolver",
              "config": {
                "endpoint": "http://pingam.devnetwork.dev:8081/am/oauth2/introspect",
                "providerHandler": {
                  "type": "Chain",
                  "config": {
                    "filters": [
                      {
                        "type": "HttpBasicAuthenticationClientFilter",
                        "config": {
                          "username": "gateway-agent",
                          "passwordSecretId": "agent.secret.id"
                        }
                      }
                    ],
                    "handler": "ForgeRockClientHandler"
                  }
                }
              }
            }
          }
        },
        {
          "name": "HeaderFilter-AddSecurityHeaders",
          "type": "HeaderFilter",
          "config": {
            "messageType": "RESPONSE",
            "add": {
              "Strict-Transport-Security": ["max-age=31536000; includeSubDomains"],
              "X-Frame-Options": ["DENY"],
              "X-Content-Type-Options": ["nosniff"],
              "X-XSS-Protection": ["1; mode=block"],
              "Content-Security-Policy": ["default-src 'self'"],
              "Referrer-Policy": ["no-referrer"]
            }
          }
        }
      ],
      "handler": "ReverseProxyHandler"
    }
  }
}
```

### Step 7: Compliance Monitoring

#### Create Monitoring Script

Create file: `scripts/compliance-check.ps1`
```powershell
# ForgeRock DoD Zero Trust Compliance Check
# Run daily to verify security posture

param(
    [string]$LogPath = "$env:USERPROFILE\Documents\PingData\compliance-logs"
)

# Create log directory
New-Item -ItemType Directory -Force -Path $LogPath | Out-Null

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = "$LogPath\compliance-check-$timestamp.log"

function Write-ComplianceLog {
    param([string]$Message, [string]$Level = "INFO")
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Host $logEntry
}

Write-ComplianceLog "Starting DoD Zero Trust Compliance Check" "INFO"

# Check 1: Verify all services are running
Write-ComplianceLog "Checking service health..." "INFO"
$services = @("pingds.devnetwork.dev", "pingam.devnetwork.dev", "pingidm.devnetwork.dev", "pinggateway.devnetwork.dev")
foreach ($service in $services) {
    $status = docker inspect --format='{{.State.Health.Status}}' $service 2>$null
    if ($status -eq "healthy") {
        Write-ComplianceLog "✓ $service is healthy" "PASS"
    } else {
        Write-ComplianceLog "✗ $service is NOT healthy (Status: $status)" "FAIL"
    }
}

# Check 2: Verify TLS configuration
Write-ComplianceLog "Checking TLS configuration..." "INFO"
$tlsCheck = docker exec pingam.devnetwork.dev cat /opt/am/config/tls-config.json 2>$null
if ($tlsCheck -match "TLSv1.2" -and $tlsCheck -match "TLSv1.3") {
    Write-ComplianceLog "✓ TLS 1.2/1.3 enabled" "PASS"
} else {
    Write-ComplianceLog "✗ TLS configuration issue" "FAIL"
}

# Check 3: Verify audit logging
Write-ComplianceLog "Checking audit logs..." "INFO"
$auditLogs = docker exec pingam.devnetwork.dev ls -la /opt/am/data/audit 2>$null
if ($auditLogs) {
    Write-ComplianceLog "✓ Audit logs present" "PASS"
} else {
    Write-ComplianceLog "✗ Audit logs missing" "FAIL"
}

# Check 4: Verify session timeout configuration
Write-ComplianceLog "Checking session timeouts..." "INFO"
# Add actual check based on your configuration

# Check 5: Verify failed login attempts protection
Write-ComplianceLog "Checking brute force protection..." "INFO"
# Add actual check based on your configuration

# Check 6: Verify password complexity
Write-ComplianceLog "Checking password policies..." "INFO"
# Add actual check based on your configuration

Write-ComplianceLog "Compliance check completed" "INFO"
Write-ComplianceLog "Log saved to: $logFile" "INFO"
```

Schedule this script:
```powershell
# Create scheduled task to run daily
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File `"$PWD\scripts\compliance-check.ps1`""

$trigger = New-ScheduledTaskTrigger -Daily -At "02:00AM"

Register-ScheduledTask -TaskName "ForgeRock-ComplianceCheck" `
    -Action $action `
    -Trigger $trigger `
    -Description "Daily DoD Zero Trust compliance check for ForgeRock stack"
```

---

## Verification & Testing

### Step 1: Service Health Checks

```powershell
# Check all containers are running
docker-compose ps

# Expected output:
# NAME                        STATUS              PORTS
# pingds.devnetwork.dev       Up (healthy)        0.0.0.0:1389->1389/tcp, ...
# pingam.devnetwork.dev       Up (healthy)        0.0.0.0:8081->8080/tcp, ...
# pingidm.devnetwork.dev      Up (healthy)        0.0.0.0:8082->8080/tcp, ...
# pinggateway.devnetwork.dev  Up (healthy)        0.0.0.0:8083->8080/tcp, ...
```

### Step 2: Test Directory Services (PingDS)

```powershell
# Test LDAP connectivity
docker exec pingds.devnetwork.dev /opt/opendj/bin/ldapsearch `
    --hostname localhost `
    --port 1389 `
    --bindDN "cn=Directory Manager" `
    --bindPassword "password" `
    --baseDN "dc=example,dc=com" `
    --searchScope base `
    "(objectclass=*)"

# Should return base DN entry
```

### Step 3: Test Access Management (PingAM)

```powershell
# Test AM console access
$amUrl = "http://localhost:8081/am/console"
$response = Invoke-WebRequest -Uri $amUrl -UseBasicParsing

if ($response.StatusCode -eq 200) {
    Write-Host "✓ PingAM console accessible" -ForegroundColor Green
} else {
    Write-Host "✗ PingAM console not accessible" -ForegroundColor Red
}

# Test authentication API
$authUrl = "http://localhost:8081/am/json/authenticate"
$credentials = @{
    authIndexType = "service"
    authIndexValue = "ldapService"
} | ConvertTo-Json

try {
    $authResponse = Invoke-RestMethod -Uri $authUrl `
        -Method POST `
        -Body $credentials `
        -ContentType "application/json" `
        -Headers @{
            "X-OpenAM-Username" = "amadmin"
            "X-OpenAM-Password" = "<AM_ADMIN_PASSWORD>"
        }

    Write-Host "✓ Authentication successful" -ForegroundColor Green
    Write-Host "Token: $($authResponse.tokenId)"
} catch {
    Write-Host "✗ Authentication failed: $_" -ForegroundColor Red
}
```

### Step 4: Test Identity Management (PingIDM)

```powershell
# Test IDM info endpoint
$idmUrl = "http://localhost:8082/openidm/info/ping"
$idmUser = "openidm-admin"
$idmPass = "<IDM_ADMIN_PASSWORD>"

$secpass = ConvertTo-SecureString $idmPass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($idmUser, $secpass)

try {
    $idmResponse = Invoke-RestMethod -Uri $idmUrl -Method GET -Credential $credential
    Write-Host "✓ PingIDM accessible" -ForegroundColor Green
    Write-Host "IDM State: $($idmResponse.state)"
} catch {
    Write-Host "✗ PingIDM not accessible: $_" -ForegroundColor Red
}
```

### Step 5: Test Identity Gateway (PingGateway)

```powershell
# Test gateway health endpoint
$gatewayUrl = "http://localhost:8083/health"
$gwResponse = Invoke-WebRequest -Uri $gatewayUrl -UseBasicParsing

if ($gwResponse.StatusCode -eq 200) {
    Write-Host "✓ PingGateway accessible" -ForegroundColor Green
} else {
    Write-Host "✗ PingGateway not accessible" -ForegroundColor Red
}
```

### Step 6: End-to-End Integration Test

Create test script: `scripts/e2e-test.ps1`
```powershell
# End-to-End ForgeRock Integration Test

Write-Host "=== ForgeRock E2E Test ===" -ForegroundColor Cyan

# Test user credentials (use actual AD test user)
$testUser = "testuser"
$testPass = "TestPassword123!"

# Step 1: Authenticate via PingAM
Write-Host "`n1. Testing authentication..." -ForegroundColor Yellow
$amUrl = "http://localhost:8081/am"
$authResponse = Invoke-RestMethod -Uri "$amUrl/json/authenticate" `
    -Method POST `
    -ContentType "application/json" `
    -Headers @{
        "X-OpenAM-Username" = $testUser
        "X-OpenAM-Password" = $testPass
    }

if ($authResponse.tokenId) {
    Write-Host "✓ Authentication successful" -ForegroundColor Green
    $token = $authResponse.tokenId
} else {
    Write-Host "✗ Authentication failed" -ForegroundColor Red
    exit 1
}

# Step 2: Validate token
Write-Host "`n2. Testing token validation..." -ForegroundColor Yellow
$validateResponse = Invoke-RestMethod -Uri "$amUrl/json/sessions/$token" `
    -Method POST `
    -ContentType "application/json" `
    -Headers @{"Cookie" = "iPlanetDirectoryPro=$token"}

if ($validateResponse.valid) {
    Write-Host "✓ Token valid" -ForegroundColor Green
} else {
    Write-Host "✗ Token invalid" -ForegroundColor Red
}

# Step 3: Get OAuth2 token
Write-Host "`n3. Testing OAuth2 flow..." -ForegroundColor Yellow
# This requires user interaction for auth code flow
# Simplified test using client credentials (if configured)

# Step 4: Test protected resource via Gateway
Write-Host "`n4. Testing protected resource access..." -ForegroundColor Yellow
try {
    $gatewayResponse = Invoke-RestMethod -Uri "http://localhost:8083/protected" `
        -Method GET `
        -Headers @{"Cookie" = "iPlanetDirectoryPro=$token"}
    Write-Host "✓ Protected resource accessible" -ForegroundColor Green
} catch {
    Write-Host "✗ Protected resource not accessible (expected if not configured yet)" -ForegroundColor Yellow
}

# Step 5: Logout
Write-Host "`n5. Testing logout..." -ForegroundColor Yellow
$logoutResponse = Invoke-RestMethod -Uri "$amUrl/json/sessions?_action=logout" `
    -Method POST `
    -ContentType "application/json" `
    -Headers @{"Cookie" = "iPlanetDirectoryPro=$token"}

Write-Host "✓ Logout successful" -ForegroundColor Green

Write-Host "`n=== E2E Test Complete ===" -ForegroundColor Cyan
```

---

## Backup & Recovery

### Backup Strategy

#### Automated Backup Script

Create: `scripts/backup.ps1`
```powershell
# ForgeRock Backup Script
# Run daily via scheduled task

param(
    [string]$BackupPath = "$env:USERPROFILE\Documents\PingBackups",
    [int]$RetentionDays = 30
)

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupDir = "$BackupPath\backup-$timestamp"

Write-Host "Starting ForgeRock backup..." -ForegroundColor Cyan

# Create backup directory
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

# Backup 1: Configuration files
Write-Host "Backing up configuration files..." -ForegroundColor Yellow
Copy-Item -Path ".\config" -Destination "$backupDir\config" -Recurse
Copy-Item -Path ".\docker-compose.yml" -Destination "$backupDir\"
Copy-Item -Path ".\.env" -Destination "$backupDir\"

# Backup 2: Persistent data volumes
Write-Host "Backing up persistent data..." -ForegroundColor Yellow
$services = @("pingds", "pingam", "pingidm", "pinggateway")

foreach ($service in $services) {
    Write-Host "  Backing up $service data..." -ForegroundColor Gray

    # Export container data
    docker run --rm `
        --volumes-from "$service.devnetwork.dev" `
        -v "${backupDir}:/backup" `
        busybox `
        tar czf "/backup/$service-data.tar.gz" /opt
}

# Backup 3: Database export (PingDS)
Write-Host "Exporting directory data..." -ForegroundColor Yellow
docker exec pingds.devnetwork.dev /opt/opendj/bin/export-ldif `
    --hostname localhost `
    --port 4444 `
    --bindDN "cn=Directory Manager" `
    --bindPassword "password" `
    --backendID userRoot `
    --ldifFile /opt/opendj/data/backup-$timestamp.ldif `
    --trustAll

docker cp "pingds.devnetwork.dev:/opt/opendj/data/backup-$timestamp.ldif" "$backupDir\"

# Backup 4: PingAM configuration export
Write-Host "Exporting AM configuration..." -ForegroundColor Yellow
# Use Amster or REST API to export AM configuration
# Example placeholder - implement based on your needs

# Compress entire backup
Write-Host "Compressing backup..." -ForegroundColor Yellow
Compress-Archive -Path "$backupDir\*" -DestinationPath "$backupDir.zip"
Remove-Item -Path $backupDir -Recurse -Force

# Cleanup old backups
Write-Host "Cleaning up old backups..." -ForegroundColor Yellow
Get-ChildItem -Path $BackupPath -Filter "backup-*.zip" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) } |
    Remove-Item -Force

Write-Host "Backup completed: $backupDir.zip" -ForegroundColor Green
```

#### Schedule Backup

```powershell
# Create scheduled task for daily backup
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File `"$PWD\scripts\backup.ps1`""

$trigger = New-ScheduledTaskTrigger -Daily -At "02:00AM"

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable

Register-ScheduledTask -TaskName "ForgeRock-DailyBackup" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Daily backup of ForgeRock Identity Platform"

Write-Host "Backup scheduled for 2:00 AM daily" -ForegroundColor Green
```

### Recovery Procedures

#### Full Stack Recovery

Create: `scripts/restore.ps1`
```powershell
# ForgeRock Restore Script

param(
    [Parameter(Mandatory=$true)]
    [string]$BackupFile
)

Write-Host "Starting ForgeRock restore..." -ForegroundColor Cyan

# Verify backup file exists
if (!(Test-Path $BackupFile)) {
    Write-Host "Error: Backup file not found: $BackupFile" -ForegroundColor Red
    exit 1
}

# Stop services
Write-Host "Stopping services..." -ForegroundColor Yellow
docker-compose down

# Extract backup
$extractPath = "$env:TEMP\forgerock-restore"
Write-Host "Extracting backup..." -ForegroundColor Yellow
Expand-Archive -Path $BackupFile -DestinationPath $extractPath -Force

# Restore configuration
Write-Host "Restoring configuration..." -ForegroundColor Yellow
Copy-Item -Path "$extractPath\config" -Destination ".\config" -Recurse -Force
Copy-Item -Path "$extractPath\docker-compose.yml" -Destination ".\" -Force
Copy-Item -Path "$extractPath\.env" -Destination ".\" -Force

# Restore data volumes
Write-Host "Restoring data volumes..." -ForegroundColor Yellow
$services = @("pingds", "pingam", "pingidm", "pinggateway")

foreach ($service in $services) {
    Write-Host "  Restoring $service data..." -ForegroundColor Gray

    $tarFile = "$extractPath\$service-data.tar.gz"
    if (Test-Path $tarFile) {
        # Create temporary container to restore data
        docker run --rm `
            -v "${service}_data:/opt" `
            -v "${extractPath}:/backup" `
            busybox `
            tar xzf "/backup/$service-data.tar.gz"
    }
}

# Restore directory data
Write-Host "Restoring directory data..." -ForegroundColor Yellow
$ldifFile = Get-ChildItem -Path $extractPath -Filter "backup-*.ldif" | Select-Object -First 1

if ($ldifFile) {
    docker cp $ldifFile.FullName "pingds.devnetwork.dev:/tmp/restore.ldif"
    docker exec pingds.devnetwork.dev /opt/opendj/bin/import-ldif `
        --hostname localhost `
        --port 4444 `
        --bindDN "cn=Directory Manager" `
        --bindPassword "password" `
        --backendID userRoot `
        --ldifFile /tmp/restore.ldif `
        --trustAll
}

# Start services
Write-Host "Starting services..." -ForegroundColor Yellow
docker-compose up -d

# Wait for services to be healthy
Write-Host "Waiting for services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

# Verify services
Write-Host "Verifying services..." -ForegroundColor Yellow
docker-compose ps

# Cleanup
Remove-Item -Path $extractPath -Recurse -Force

Write-Host "Restore completed" -ForegroundColor Green
```

---

## Troubleshooting

### Common Issues

#### Issue 1: Services Won't Start

**Symptoms:**
- Containers exit immediately
- Health checks fail
- "Unhealthy" status

**Solutions:**

```powershell
# Check container logs
docker-compose logs pingds
docker-compose logs pingam

# Check resource allocation
docker stats

# Verify ports aren't in use
netstat -ano | findstr "8081"

# Reset and restart
docker-compose down -v  # WARNING: This removes volumes!
docker-compose up -d
```

#### Issue 2: Cannot Connect to Active Directory

**Symptoms:**
- LDAP bind failures
- "Can't contact LDAP server"
- Authentication failures

**Solutions:**

```powershell
# Test AD connectivity from container
docker exec pingds.devnetwork.dev ldapsearch `
    -H ldap://192.168.1.2:389 `
    -D "CN=svc-forgerock,CN=Users,DC=devnetwork,DC=dev" `
    -w "password" `
    -b "DC=devnetwork,DC=dev" `
    "(objectClass=user)"

# Check firewall rules on AD
# On Domain Controller:
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*LDAP*" }

# Verify service account password
# Check account is not locked/disabled in AD
```

#### Issue 3: Memory Issues

**Symptoms:**
- Services crash with "Out of Memory"
- Slow performance
- Docker Desktop warnings

**Solutions:**

```powershell
# Check memory usage
docker stats --no-stream

# Increase Docker Desktop memory allocation
# Settings → Resources → Advanced → Memory: 16 GB

# Adjust JVM heap sizes in .env or docker-compose.yml
# Example for PingAM:
# CATALINA_OPTS=-server -Xmx4g -Xms4g
```

#### Issue 4: SSL/TLS Certificate Issues

**Symptoms:**
- "Certificate verify failed"
- "SSL handshake failed"
- HTTPS connections fail

**Solutions:**

```powershell
# Trust self-signed CA certificate
# Export CA cert
docker cp pingam.devnetwork.dev:/opt/am/security/keys/keystore.jks ./keystore.jks

# Import to Windows trust store
Import-Certificate -FilePath ".\certs\ca-cert.pem" `
    -CertStoreLocation Cert:\LocalMachine\Root

# Or disable SSL verification for testing (NOT for production!)
```

### Diagnostic Commands

```powershell
# Full system diagnostic
Write-Host "=== ForgeRock System Diagnostic ===" -ForegroundColor Cyan

# Check Docker
Write-Host "`nDocker Version:" -ForegroundColor Yellow
docker version

# Check Compose
Write-Host "`nDocker Compose Version:" -ForegroundColor Yellow
docker-compose version

# Check running containers
Write-Host "`nRunning Containers:" -ForegroundColor Yellow
docker-compose ps

# Check resource usage
Write-Host "`nResource Usage:" -ForegroundColor Yellow
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Check networks
Write-Host "`nNetworks:" -ForegroundColor Yellow
docker network ls

# Check volumes
Write-Host "`nVolumes:" -ForegroundColor Yellow
docker volume ls | Select-String "ping"

# Check logs for errors
Write-Host "`nRecent Errors:" -ForegroundColor Yellow
docker-compose logs --tail=50 | Select-String -Pattern "ERROR|SEVERE|FATAL"

# Check disk space
Write-Host "`nDisk Space:" -ForegroundColor Yellow
Get-PSDrive C | Select-Object Used, Free

Write-Host "`n=== Diagnostic Complete ===" -ForegroundColor Cyan
```

---

## Migration to Air-Gapped Environment

### Pre-Migration Checklist

1. ✅ Verify all services working in dev environment
2. ✅ Export all Docker images to TAR files
3. ✅ Backup all configuration files
4. ✅ Document custom configurations
5. ✅ Export SSL certificates
6. ✅ Create deployment documentation
7. ✅ Test restore procedures

### Migration Steps

#### Step 1: Package Everything for Transfer

```powershell
# Create migration package
$migrationPath = "$env:USERPROFILE\Documents\ForgeRock-Migration"
New-Item -ItemType Directory -Force -Path $migrationPath

Write-Host "Creating migration package..." -ForegroundColor Cyan

# Copy project files
Copy-Item -Path ".\docker-compose.yml" -Destination $migrationPath
Copy-Item -Path ".\.env" -Destination $migrationPath
Copy-Item -Path ".\config" -Destination "$migrationPath\config" -Recurse
Copy-Item -Path ".\scripts" -Destination "$migrationPath\scripts" -Recurse
Copy-Item -Path ".\certs" -Destination "$migrationPath\certs" -Recurse
Copy-Item -Path ".\instructions.md" -Destination $migrationPath

# Export images (should already be done - see Private Registry section)
# Verify images are present
$imageArchives = Get-ChildItem -Path "$env:USERPROFILE\Documents\ForgeRockImages\*.tar"
Copy-Item -Path "$env:USERPROFILE\Documents\ForgeRockImages" -Destination "$migrationPath\images" -Recurse

# Create deployment checklist
$checklist = @"
# ForgeRock Air-Gapped Deployment Checklist

## Pre-Deployment
- [ ] Windows Server 2019 installed and updated
- [ ] Docker Desktop installed
- [ ] Network connectivity to Domain Controllers verified
- [ ] Service accounts created in Active Directory
- [ ] SSL certificates prepared (if using custom)
- [ ] Firewall rules configured

## Files to Transfer
- [ ] docker-compose.yml
- [ ] .env (update with production values!)
- [ ] config/ directory
- [ ] scripts/ directory
- [ ] certs/ directory
- [ ] images/ directory (Docker TAR files)
- [ ] instructions.md

## Deployment Steps
1. [ ] Copy all files to target server
2. [ ] Load Docker images
3. [ ] Update .env with production values
4. [ ] Create directory structure
5. [ ] Start services: docker-compose up -d
6. [ ] Verify service health
7. [ ] Configure AD integration
8. [ ] Test authentication
9. [ ] Configure ServiceNow integration
10. [ ] Run compliance checks
11. [ ] Setup backup schedule

## Post-Deployment
- [ ] Document production URLs
- [ ] Train administrators
- [ ] Setup monitoring
- [ ] Schedule regular backups
- [ ] Document support procedures
"@

$checklist | Out-File -FilePath "$migrationPath\DEPLOYMENT-CHECKLIST.md"

# Compress for transfer
Write-Host "Compressing migration package..." -ForegroundColor Yellow
Compress-Archive -Path "$migrationPath\*" -DestinationPath "$migrationPath.zip" -Force

Write-Host "`nMigration package created:" -ForegroundColor Green
Write-Host "$migrationPath.zip" -ForegroundColor Cyan
Write-Host "`nTransfer this file to your air-gapped environment" -ForegroundColor Yellow
```

#### Step 2: Deploy in Air-Gapped Environment

On the target air-gapped server:

```powershell
# Extract migration package
$migrationZip = "C:\Transfer\ForgeRock-Migration.zip"
$deployPath = "$env:USERPROFILE\Documents\ping"

Expand-Archive -Path $migrationZip -DestinationPath $deployPath -Force

cd $deployPath

# Load Docker images
Write-Host "Loading Docker images..." -ForegroundColor Cyan
$imageFiles = Get-ChildItem -Path ".\images\*.tar"

foreach ($imageFile in $imageFiles) {
    Write-Host "Loading $($imageFile.Name)..." -ForegroundColor Yellow
    docker load -i $imageFile.FullName
}

# Verify images loaded
docker images | Select-String "forgerock"

# Update .env with production values
Write-Host "`nIMPORTANT: Update .env file with production values!" -ForegroundColor Red
notepad .env

# Create directory structure
Write-Host "Creating directory structure..." -ForegroundColor Yellow
.\scripts\create-directories.ps1

# Deploy
Write-Host "Starting deployment..." -ForegroundColor Cyan
docker-compose up -d

# Monitor startup
Write-Host "Monitoring startup (this will take 10-15 minutes)..." -ForegroundColor Yellow
docker-compose logs -f
```

### Post-Migration Validation

```powershell
# Run full system test
.\scripts\e2e-test.ps1

# Run compliance check
.\scripts\compliance-check.ps1

# Verify AD integration
# (Follow steps in Active Directory Integration section)

# Test ServiceNow integration
# (Follow steps in ServiceNow Integration section)
```

---

## Best Practices

### Security Best Practices

1. **Credential Management**
   - Change all default passwords immediately
   - Use minimum 15-character passwords with complexity
   - Rotate passwords every 90 days
   - Store credentials in encrypted vault (not in .env for production)

2. **Certificate Management**
   - Use proper CA-signed certificates in production
   - Renew certificates before expiration (automate with Let's Encrypt or internal CA)
   - Monitor certificate expiration dates
   - Use strong key sizes (minimum 2048-bit RSA or 256-bit ECC)

3. **Network Security**
   - Segment ForgeRock services on dedicated VLAN
   - Use firewall rules to restrict access
   - Implement IDS/IPS monitoring
   - Enable logging for all network traffic

4. **Audit & Logging**
   - Send logs to centralized SIEM
   - Retain logs per DoD requirements (minimum 1 year)
   - Regular log review and analysis
   - Alert on suspicious activities

5. **Patch Management**
   - Subscribe to ForgeRock security advisories
   - Test patches in dev before production
   - Maintain patching schedule
   - Document patch history

### Operational Best Practices

1. **Monitoring**
   - Implement health checks for all services
   - Monitor resource utilization
   - Set up alerting for service failures
   - Track authentication success/failure rates

2. **Backup & Recovery**
   - Daily automated backups
   - Test restore procedures monthly
   - Store backups in separate location
   - Document recovery procedures

3. **Capacity Planning**
   - Monitor growth trends
   - Plan for 3x expected load
   - Test scalability before scaling
   - Document performance baselines

4. **Documentation**
   - Keep runbooks up-to-date
   - Document all custom configurations
   - Maintain architecture diagrams
   - Record all changes in change log

### Windows Server Specific

1. **Docker Desktop**
   - Keep Docker Desktop updated
   - Monitor Windows event logs
   - Configure proper resource allocation
   - Use WSL2 backend for better performance

2. **File System**
   - Use NTFS compression for backup storage
   - Regular disk cleanup
   - Monitor disk I/O performance
   - Consider SSD for persistent data

3. **Updates**
   - Windows Update schedule
   - Test updates in dev first
   - Coordinate with Docker updates
   - Maintain update log

---

## Additional Resources

### ForgeRock Documentation

- ForgeRock Platform Documentation: https://backstage.forgerock.com/docs/
- ForgeRock Identity Platform 8.0: https://backstage.forgerock.com/docs/platform/8
- ForgeRock Community: https://community.forgerock.com/

### DoD Zero Trust

- DoD Zero Trust Reference Architecture: https://dodcio.defense.gov/Portals/0/Documents/Library/ZT-RA.pdf
- NIST SP 800-207: Zero Trust Architecture: https://csrc.nist.gov/publications/detail/sp/800-207/final

### Docker

- Docker Desktop for Windows: https://docs.docker.com/desktop/windows/
- Docker Compose Reference: https://docs.docker.com/compose/compose-file/

### Support Contacts

- ForgeRock Support: https://backstage.forgerock.com/support
- Docker Support: https://www.docker.com/support

---

## Appendix

### A. Environment Variables Reference

See `.env` file for complete list with descriptions.

### B. Port Reference

| Service | HTTP Port | HTTPS Port | Other Ports | Purpose |
|---------|-----------|------------|-------------|---------|
| PingDS | 8080 | 8443 | 1389 (LDAP), 1636 (LDAPS), 4444 (Admin) | Directory Services |
| PingAM | 8081 | 8444 | - | Access Management |
| PingIDM | 8082 | 8445 | - | Identity Management |
| PingGateway | 8083 | 8446 | - | Identity Gateway |

### C. Default Credentials (Change Immediately!)

| Service | Username | Password Variable | Default |
|---------|----------|-------------------|---------|
| PingDS | cn=Directory Manager | DS_PASSWORD | password |
| PingAM | amadmin | AM_ADMIN_PASSWORD | password |
| PingIDM | openidm-admin | IDM_ADMIN_PASSWORD | password |

### D. File Structure Reference

```
ping/
├── docker-compose.yml          # Main orchestration file
├── .env                        # Environment variables
├── instructions.md             # This file
├── config/                     # Service configurations
│   ├── ds/                     # PingDS configs
│   ├── am/                     # PingAM configs
│   ├── idm/                    # PingIDM configs
│   └── gateway/                # PingGateway configs
├── scripts/                    # Utility scripts
│   ├── backup.ps1
│   ├── restore.ps1
│   ├── compliance-check.ps1
│   └── e2e-test.ps1
├── certs/                      # SSL/TLS certificates
└── secrets/                    # Sensitive files (gitignored)
```

---

**Version:** 1.0
**Last Updated:** 2024
**Author:** ForgeRock DevOps Team
**Classification:** Internal Use - Zero Trust Implementation

---

*End of Instructions*
