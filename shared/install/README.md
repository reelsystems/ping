# Ping Identity Installation Files

This directory should contain the extracted Ping Identity distributions.

## Required Files

After downloading from ForgeRock Backstage (https://backstage.forgerock.com), extract the distributions here:

### Directory Structure

```
shared/install/
├── opendj/              # PingDS 7.5.2 extracted here
│   ├── bin/
│   ├── lib/
│   ├── setup
│   └── ...
│
├── openidm/             # PingIDM 7.5.2 extracted here
│   ├── bin/
│   ├── conf/
│   ├── connectors/
│   ├── startup.sh
│   └── ...
│
├── AM-7.5.2.war         # PingAM 7.5.2 WAR file (or extracted AM directory)
│
└── README.md            # This file
```

## Download Instructions

1. **Sign in to ForgeRock Backstage**:
   - URL: https://backstage.forgerock.com
   - Create account if needed

2. **Download PingDS 7.5.2**:
   - Navigate to: Downloads > Directory Services > DS 7.5.2
   - Download: `DS-7.5.2.zip`
   - Extract to: `shared/install/opendj/`
   - Command: `unzip DS-7.5.2.zip -d shared/install/ && mv shared/install/opendj shared/install/opendj`

3. **Download PingIDM 7.5.2**:
   - Navigate to: Downloads > Identity Management > IDM 7.5.2
   - Download: `IDM-7.5.2.zip`
   - Extract to: `shared/install/openidm/`
   - Command: `unzip IDM-7.5.2.zip -d shared/install/ && mv shared/install/openidm shared/install/openidm`

4. **Download PingAM 7.5.2**:
   - Navigate to: Downloads > Access Management > AM 7.5.2
   - Download: `AM-7.5.2.zip`
   - Extract and copy WAR file to: `shared/install/AM-7.5.2.war`
   - Command: `unzip AM-7.5.2.zip && cp AM-7.5.2/AM-7.5.2.war shared/install/`

## Verification

After extraction, verify the structure:

```bash
# Check PingDS
ls -la shared/install/opendj/bin/setup
ls -la shared/install/opendj/bin/start-ds

# Check PingIDM
ls -la shared/install/openidm/startup.sh
ls -la shared/install/openidm/bin/

# Check PingAM
ls -la shared/install/AM-7.5.2.war
```

All files should exist and be readable.

## Important Notes

- **Do not commit these files to version control** - they are large binary files
- The `.gitignore` should exclude `shared/install/*` (except this README)
- Ensure proper file permissions after extraction
- Total size will be approximately 1-2 GB after all extractions

## Troubleshooting

**Issue**: "File not found" when starting containers
- **Solution**: Verify extraction paths match exactly as shown above

**Issue**: Permission denied
- **Solution**: `chmod +x shared/install/opendj/setup` and similar for other executables

**Issue**: Download access denied
- **Solution**: Ensure you have an active ForgeRock/Ping Identity support account

---

For questions, refer to: https://docs.pingidentity.com
