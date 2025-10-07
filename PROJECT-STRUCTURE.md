# ForgeRock Identity Platform - Project Structure

## Complete File Listing

```
ping/
│
├── 📄 docker-compose.yml              # Main Docker Compose orchestration file
├── 📄 .env                            # Environment variables (🔒 SENSITIVE - not in repo)
├── 📄 .gitignore                      # Git ignore rules for sensitive files
│
├── 📘 README.md                       # Project overview and quick reference
├── 📘 QUICKSTART.md                   # 5-step quick start guide
├── 📘 instructions.md                 # Complete 80+ page deployment guide
├── 📘 DEPLOYMENT-SUMMARY.md           # Deployment summary and architecture
├── 📘 PROJECT-STRUCTURE.md            # This file - project structure reference
│
├── 📁 config/                         # Service configuration files
│   ├── 📁 ds/                         # PingDS (Directory Services) configs
│   │   ├── .gitkeep
│   │   └── README.md
│   │
│   ├── 📁 am/                         # PingAM (Access Management) configs
│   │   ├── .gitkeep
│   │   ├── README.md
│   │   ├── audit-config.example.json  # DoD-compliant audit configuration
│   │   ├── 📁 services/               # Service-specific configs (OAuth2, SAML)
│   │   │   └── .gitkeep
│   │   └── 📁 realms/                 # Realm configurations
│   │       └── .gitkeep
│   │
│   ├── 📁 idm/                        # PingIDM (Identity Management) configs
│   │   ├── .gitkeep
│   │   ├── README.md
│   │   ├── ad-connector.example.json  # Active Directory connector config
│   │   ├── sync-mapping.example.json  # AD sync mapping configuration
│   │   ├── 📁 conf/                   # IDM configuration files
│   │   │   └── .gitkeep
│   │   └── 📁 script/                 # Custom scripts for workflows
│   │       └── .gitkeep
│   │
│   └── 📁 gateway/                    # PingGateway (Identity Gateway) configs
│       ├── .gitkeep
│       ├── README.md
│       ├── servicenow-route.example.json  # ServiceNow protection route
│       └── 📁 routes/                 # Route definitions for protected apps
│           └── .gitkeep
│
├── 📁 scripts/                        # Utility PowerShell scripts
│   ├── create-directories.ps1         # Sets up directory structure
│   ├── backup.ps1                     # Automated backup with retention
│   ├── restore.ps1                    # Full restore from backup
│   ├── health-check.ps1               # Comprehensive health check
│   │
│   ├── 📁 ds/                         # DS-specific scripts
│   │   └── .gitkeep
│   ├── 📁 am/                         # AM-specific scripts
│   │   └── .gitkeep
│   ├── 📁 idm/                        # IDM-specific scripts
│   │   └── .gitkeep
│   └── 📁 gateway/                    # Gateway-specific scripts
│       └── .gitkeep
│
├── 📁 secrets/                        # 🔒 Sensitive files (NOT in version control)
│   └── README.md                      # Security guidelines
│
└── 📁 certs/                          # SSL/TLS certificates
    └── README.md                      # Certificate generation instructions
```

## Files Created After Running Scripts

```
%USERPROFILE%\Documents\
│
├── 📁 PingData/                       # Persistent data (Docker volumes)
│   ├── 📁 ds/                         # Directory Services data
│   │   ├── data/                      # LDAP data
│   │   ├── config/                    # DS configuration
│   │   └── logs/                      # DS logs
│   │
│   ├── 📁 am/                         # Access Management data
│   │   ├── data/                      # Session data
│   │   ├── config/                    # AM configuration
│   │   ├── logs/                      # AM logs
│   │   └── audit/                     # Audit logs
│   │
│   ├── 📁 idm/                        # Identity Management data
│   │   ├── data/                      # IDM data
│   │   ├── config/                    # IDM configuration
│   │   ├── logs/                      # IDM logs
│   │   └── audit/                     # Audit logs
│   │
│   └── 📁 gateway/                    # Identity Gateway data
│       ├── data/                      # Gateway data
│       ├── config/                    # Gateway configuration
│       └── logs/                      # Gateway logs
│
├── 📁 PingBackups/                    # Automated backups
│   ├── backup-2024-01-01_02-00-00.zip
│   ├── backup-2024-01-02_02-00-00.zip
│   └── ...                            # 30 days retention
│
└── 📁 ping/                           # This project directory
    └── [files as shown above]
```

## File Descriptions

### Core Configuration Files

| File | Size | Purpose | Sensitive |
|------|------|---------|-----------|
| **docker-compose.yml** | ~10 KB | Container orchestration, networking, volumes | No |
| **.env** | ~5 KB | All environment variables, passwords, paths | ⚠️ YES |
| **.gitignore** | ~1 KB | Prevents committing sensitive files | No |

### Documentation Files

| File | Size | Purpose |
|------|------|---------|
| **README.md** | ~5 KB | Project overview, quick reference |
| **QUICKSTART.md** | ~5 KB | Fast 5-step deployment guide |
| **instructions.md** | ~150 KB | Complete deployment documentation |
| **DEPLOYMENT-SUMMARY.md** | ~25 KB | Architecture and deployment summary |
| **PROJECT-STRUCTURE.md** | ~10 KB | This file - project structure |

### PowerShell Scripts

| Script | Lines | Purpose |
|--------|-------|---------|
| **create-directories.ps1** | ~180 | Creates all directories and README files |
| **backup.ps1** | ~250 | Comprehensive backup with compression |
| **restore.ps1** | ~200 | Full restore with safety checks |
| **health-check.ps1** | ~300 | Health check with scoring system |

### Configuration Examples

| File | Size | Purpose |
|------|------|---------|
| **audit-config.example.json** | ~3 KB | DoD-compliant audit logging |
| **servicenow-route.example.json** | ~5 KB | ServiceNow OAuth2 protection |
| **ad-connector.example.json** | ~6 KB | Active Directory LDAP connector |
| **sync-mapping.example.json** | ~5 KB | AD to managed user sync mapping |

## Directory Purposes

### `/config`
Contains all service-specific configuration files. These are mounted into containers as read-only volumes.

**Usage:**
- Store custom configurations here
- Override default ForgeRock settings
- Version control safe (no sensitive data)

**Example:**
```powershell
# Copy example to active config
Copy-Item config/am/audit-config.example.json config/am/audit-config.json

# Edit as needed
notepad config/am/audit-config.json
```

### `/scripts`
PowerShell automation scripts for common operations.

**Usage:**
- Run from project root directory
- All scripts support `-WhatIf` for testing
- Can be scheduled via Windows Task Scheduler

**Example:**
```powershell
# Run health check
.\scripts\health-check.ps1

# Run backup with custom retention
.\scripts\backup.ps1 -RetentionDays 90
```

### `/secrets`
🔒 **HIGHLY SENSITIVE** - Stores passwords, keys, certificates.

**Security:**
- ✅ Excluded from Git via `.gitignore`
- ✅ NTFS permissions restricted to current user
- ✅ Should be encrypted at rest (EFS/BitLocker)

**Contents:**
- Password files (`.txt`)
- Private keys (`.pem`, `.key`)
- Keystores (`.jks`, `.p12`)
- API keys and tokens

### `/certs`
SSL/TLS certificates for HTTPS communication.

**Contents:**
- CA certificate and key
- Service certificates (DS, AM, IDM, Gateway)
- Trusted CA bundle

**Example:**
```
certs/
├── ca-cert.pem              # Root CA certificate
├── ca-key.pem               # CA private key
├── pingds-cert.pem          # DS server certificate
├── pingds-key.pem           # DS private key
├── pingam-cert.pem          # AM server certificate
├── pingam-key.pem           # AM private key
└── ...
```

## Docker Volumes

Docker Compose creates named volumes that map to Windows directories:

```yaml
volumes:
  pingds-data:
    device: %USERPROFILE%/Documents/PingData/ds

  pingam-data:
    device: %USERPROFILE%/Documents/PingData/am

  pingidm-data:
    device: %USERPROFILE%/Documents/PingData/idm

  pinggateway-data:
    device: %USERPROFILE%/Documents/PingData/gateway
```

**Benefits:**
- ✅ Data persists across container restarts
- ✅ Easy to backup (standard Windows paths)
- ✅ Can be accessed with Windows tools
- ✅ Supports Windows file permissions

## Important Files (Must Update Before Deployment)

### 1. `.env` File
**Location:** `/ping/.env`
**Status:** 🔴 MUST UPDATE

```ini
# Critical values to change:
DEPLOYMENT_KEY=changeme_generate_secure_key_here     # Generate new!
DS_PASSWORD=ChangeMeDS2024!                          # Change!
AM_ADMIN_PASSWORD=ChangeMeAM2024!                    # Change!
IDM_ADMIN_PASSWORD=ChangeMeIDM2024!                  # Change!
AD_BIND_PASSWORD=ChangeMe_AD_ServiceAccount2024!     # Update with AD password
SNOW_INSTANCE_URL=https://your-instance.service-now.com  # Update
```

### 2. Active Directory Service Account
**Required Before Deployment:**

1. Create in AD:
   - Username: `svc-forgerock`
   - Password: Strong password (15+ chars)
   - Password never expires: ✅
   - User cannot change password: ✅

2. Grant permissions:
   - Read access to Users/Groups OUs
   - Add to Domain Users

3. Update `.env`:
   ```ini
   AD_BIND_DN=CN=svc-forgerock,CN=Users,DC=devnetwork,DC=dev
   AD_BIND_PASSWORD=<your AD service account password>
   ```

## Workflow: First Deployment

### Step 1: Prepare Files

```powershell
# Navigate to project
cd $env:USERPROFILE\Documents\ping

# Generate deployment key
$key = [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 }))
Write-Host "DEPLOYMENT_KEY=$key"

# Update .env
notepad .env  # Add key and change passwords
```

### Step 2: Create Structure

```powershell
# Run directory creation script
.\scripts\create-directories.ps1

# Verify structure
tree %USERPROFILE%\Documents\PingData
```

### Step 3: Deploy

```powershell
# Start services
docker-compose up -d

# Monitor startup (10-15 minutes)
docker-compose logs -f
```

### Step 4: Verify

```powershell
# Health check
.\scripts\health-check.ps1

# Check services
docker-compose ps
```

## File Maintenance

### Files to Back Up

**Critical (must backup):**
- ✅ `.env` file
- ✅ `config/` directory
- ✅ `secrets/` directory
- ✅ `certs/` directory
- ✅ `%USERPROFILE%\Documents\PingData\` (all service data)

**Optional (can regenerate):**
- `scripts/` directory
- Documentation files

**Automated backup includes all critical files:**
```powershell
.\scripts\backup.ps1
```

### Files Never to Commit to Git

Configured in `.gitignore`:
- ❌ `.env`
- ❌ `secrets/`
- ❌ `*.key`, `*.pem`, `*.pfx`, `*.jks`
- ❌ `PingData/`
- ❌ `PingBackups/`
- ❌ `*.log`

### Configuration Change Workflow

1. **Edit configuration:**
   ```powershell
   notepad config/am/audit-config.json
   ```

2. **Restart affected service:**
   ```powershell
   docker-compose restart pingam
   ```

3. **Verify change:**
   ```powershell
   docker-compose logs pingam
   ```

4. **Test functionality:**
   ```powershell
   .\scripts\health-check.ps1
   ```

## File Permissions (Windows)

### Recommended Permissions

| Directory/File | Permissions |
|----------------|-------------|
| `/ping` (root) | Users: Read, Admins: Full Control |
| `/secrets` | Current User ONLY: Full Control |
| `/certs` | Users: Read, Admins: Full Control |
| `.env` | Current User ONLY: Read/Write |
| `scripts/*.ps1` | Users: Read/Execute, Admins: Full Control |

### Set Restricted Permissions

```powershell
# Restrict .env file
$acl = Get-Acl ".env"
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $env:USERNAME, "FullControl", "Allow"
)
$acl.SetAccessRule($rule)
Set-Acl ".env" $acl

# Verify
Get-Acl ".env" | Format-List
```

## Size Estimates

### Initial Deployment

| Component | Size |
|-----------|------|
| Project files | ~250 KB |
| Docker images | ~2 GB |
| Initial data | ~100 MB |
| **Total** | ~2.35 GB |

### After 30 Days Operation

| Component | Size |
|-----------|------|
| Service data | ~1 GB |
| Logs (30 days) | ~500 MB |
| Audit logs | ~200 MB |
| Backups (30 days) | ~2 GB |
| **Total** | ~6 GB |

### After 1 Year Operation (with 1000 users)

| Component | Size |
|-----------|------|
| Service data | ~5 GB |
| Logs (365 days) | ~6 GB |
| Audit logs (365 days) | ~2.5 GB |
| Backups (30 days) | ~3 GB |
| **Total** | ~16.5 GB |

## Quick Reference Commands

```powershell
# List all project files
Get-ChildItem -Recurse

# Find configuration files
Get-ChildItem -Recurse -Filter "*.json"

# Find scripts
Get-ChildItem -Path scripts -Filter "*.ps1"

# Check file sizes
Get-ChildItem -Recurse | Measure-Object -Property Length -Sum

# Find recent changes
Get-ChildItem -Recurse | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) }

# Search in files
Get-ChildItem -Recurse -Filter "*.md" | Select-String "password"
```

---

**For complete deployment instructions, see [instructions.md](instructions.md)**
**For quick start, see [QUICKSTART.md](QUICKSTART.md)**
