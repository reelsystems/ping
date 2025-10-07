# ForgeRock Directory Structure Setup Script
# Creates all necessary directories for ForgeRock Identity Platform deployment

param(
    [string]$BasePath = "$env:USERPROFILE\Documents\PingData"
)

Write-Host "=== ForgeRock Directory Structure Setup ===" -ForegroundColor Cyan
Write-Host "Base Path: $BasePath`n" -ForegroundColor Yellow

# Define directory structure
$directories = @(
    # Persistent data directories
    "$BasePath\ds\data",
    "$BasePath\ds\config",
    "$BasePath\ds\logs",
    "$BasePath\am\data",
    "$BasePath\am\config",
    "$BasePath\am\logs",
    "$BasePath\am\audit",
    "$BasePath\idm\data",
    "$BasePath\idm\config",
    "$BasePath\idm\logs",
    "$BasePath\idm\audit",
    "$BasePath\gateway\data",
    "$BasePath\gateway\config",
    "$BasePath\gateway\logs",

    # Backup directory
    "$env:USERPROFILE\Documents\PingBackups\ds",
    "$env:USERPROFILE\Documents\PingBackups\am",
    "$env:USERPROFILE\Documents\PingBackups\idm",
    "$env:USERPROFILE\Documents\PingBackups\gateway",

    # Configuration directories (in project)
    ".\config\ds",
    ".\config\am",
    ".\config\am\services",
    ".\config\am\realms",
    ".\config\idm",
    ".\config\idm\conf",
    ".\config\idm\script",
    ".\config\gateway",
    ".\config\gateway\routes",

    # Scripts directories
    ".\scripts\ds",
    ".\scripts\am",
    ".\scripts\idm",
    ".\scripts\gateway",

    # Secrets directory
    ".\secrets",

    # Certificates directory
    ".\certs"
)

# Create directories
$created = 0
$existing = 0

foreach ($dir in $directories) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Write-Host "[+] Created: $dir" -ForegroundColor Green
        $created++
    } else {
        Write-Host "[✓] Exists: $dir" -ForegroundColor Gray
        $existing++
    }
}

# Create README files in key directories
$readmeContent = @{
    ".\config\ds\README.md" = @"
# PingDS Configuration

Place custom Directory Services configuration files here.

## Common Configuration Files

- **schema/**: Custom LDAP schema definitions
- **setup-profiles/**: DS setup profiles
- **config.ldif**: Directory configuration
- **backend.ldif**: Backend configuration

## Documentation

https://backstage.forgerock.com/docs/ds/8/reference/
"@

    ".\config\am\README.md" = @"
# PingAM Configuration

Place custom Access Management configuration files here.

## Common Configuration Files

- **services/**: Service configurations (OAuth2, SAML, etc.)
- **realms/**: Realm-specific configurations
- **scripts/**: Custom authentication/policy scripts
- **keystore.jks**: Keystore for signing/encryption

## Documentation

https://backstage.forgerock.com/docs/am/8/reference/
"@

    ".\config\idm\README.md" = @"
# PingIDM Configuration

Place custom Identity Management configuration files here.

## Common Configuration Files

- **conf/**: Main configuration directory
  - connector.config.json: LDAP/AD connector configs
  - sync.json: Synchronization mappings
  - router.json: Endpoint routing
  - authentication.json: Authentication configuration
- **script/**: Custom scripts for workflows

## Documentation

https://backstage.forgerock.com/docs/idm/8/reference/
"@

    ".\config\gateway\README.md" = @"
# PingGateway Configuration

Place custom Identity Gateway configuration files here.

## Common Configuration Files

- **routes/**: Route definitions for protected applications
- **config.json**: Main gateway configuration
- **admin.json**: Admin API configuration

## Documentation

https://backstage.forgerock.com/docs/ig/8/reference/
"@

    ".\secrets\README.md" = @"
# Secrets Directory

⚠️ **SECURITY WARNING**: This directory contains sensitive information!

- Never commit this directory to version control
- Restrict access permissions
- Use encrypted storage in production

## Files Stored Here

- Password files
- Private keys
- Service account credentials
- API keys
- Deployment keys

## Best Practices

1. Use Windows file encryption (EFS) for this directory
2. Regular security audits
3. Rotate secrets regularly
4. Use Azure Key Vault or similar for production
"@

    ".\certs\README.md" = @"
# Certificates Directory

SSL/TLS certificates for ForgeRock services.

## Required Certificates

- **ca-cert.pem**: Root CA certificate
- **ca-key.pem**: CA private key
- **pingds-cert.pem**: DS server certificate
- **pingam-cert.pem**: AM server certificate
- **pingidm-cert.pem**: IDM server certificate
- **pinggateway-cert.pem**: Gateway server certificate

## Generation

See instructions.md for certificate generation commands.

## Security

- Use proper CA-signed certificates in production
- Minimum 2048-bit RSA or 256-bit ECC
- Renew before expiration (automate monitoring)
"@
}

Write-Host "`nCreating README files..." -ForegroundColor Yellow
foreach ($file in $readmeContent.Keys) {
    $readmeContent[$file] | Out-File -FilePath $file -Encoding UTF8
    Write-Host "[+] Created: $file" -ForegroundColor Green
}

# Set permissions on secrets directory (Windows)
Write-Host "`nSecuring secrets directory..." -ForegroundColor Yellow
try {
    $acl = Get-Acl ".\secrets"
    $acl.SetAccessRuleProtection($true, $false)  # Disable inheritance

    # Add current user with full control
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $currentUser, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
    )
    $acl.AddAccessRule($rule)

    Set-Acl ".\secrets" $acl
    Write-Host "[✓] Secrets directory secured for user: $currentUser" -ForegroundColor Green
} catch {
    Write-Host "[!] Warning: Could not set permissions on secrets directory" -ForegroundColor Yellow
    Write-Host "    Error: $_" -ForegroundColor Yellow
}

# Create .gitkeep files for empty directories that should be tracked
$gitkeepDirs = @(
    ".\config\ds",
    ".\config\am\services",
    ".\config\am\realms",
    ".\config\idm\conf",
    ".\config\idm\script",
    ".\config\gateway\routes",
    ".\scripts\ds",
    ".\scripts\am",
    ".\scripts\idm",
    ".\scripts\gateway"
)

Write-Host "`nCreating .gitkeep files..." -ForegroundColor Yellow
foreach ($dir in $gitkeepDirs) {
    $gitkeepFile = Join-Path $dir ".gitkeep"
    if (!(Test-Path $gitkeepFile)) {
        "" | Out-File -FilePath $gitkeepFile
        Write-Host "[+] Created: $gitkeepFile" -ForegroundColor Green
    }
}

# Summary
Write-Host "`n=== Directory Structure Setup Complete ===" -ForegroundColor Cyan
Write-Host "Directories created: $created" -ForegroundColor Green
Write-Host "Directories existing: $existing" -ForegroundColor Gray
Write-Host "Total directories: $($created + $existing)" -ForegroundColor Cyan

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Review and update .env file with your configuration" -ForegroundColor White
Write-Host "2. Generate SSL/TLS certificates (see instructions.md)" -ForegroundColor White
Write-Host "3. Create service account in Active Directory" -ForegroundColor White
Write-Host "4. Start the stack: docker-compose up -d" -ForegroundColor White

Write-Host "`nFor detailed instructions, see: instructions.md" -ForegroundColor Cyan
