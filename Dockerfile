FROM mcr.microsoft.com/windows/servercore:1809

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# enable TLS 1.2
# https://docs.microsoft.com/en-us/system-center/vmm/install-tls?view=sc-vmm-1801
# https://docs.microsoft.com/en-us/windows-server/identity/ad-fs/operations/manage-ssl-protocols-in-ad-fs#enable-tls-12
RUN Write-Host 'Enabling TLS 1.2 (https://githubengineering.com/crypto-removal-notice/) ...'; \
	$tls12RegBase = 'HKLM:\\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2'; \
	if (Test-Path $tls12RegBase) { throw ('"{0}" already exists!' -f $tls12RegBase) }; \
	New-Item -Path ('{0}/Client' -f $tls12RegBase) -Force; \
	New-Item -Path ('{0}/Server' -f $tls12RegBase) -Force; \
	New-ItemProperty -Path ('{0}/Client' -f $tls12RegBase) -Name 'DisabledByDefault' -PropertyType DWORD -Value 0 -Force; \
	New-ItemProperty -Path ('{0}/Client' -f $tls12RegBase) -Name 'Enabled' -PropertyType DWORD -Value 1 -Force; \
	New-ItemProperty -Path ('{0}/Server' -f $tls12RegBase) -Name 'DisabledByDefault' -PropertyType DWORD -Value 0 -Force; \
	New-ItemProperty -Path ('{0}/Server' -f $tls12RegBase) -Name 'Enabled' -PropertyType DWORD -Value 1 -Force; \
	Write-Host 'Complete.'

ENV JAVA_HOME C:\\openjdk-11
RUN $newPath = ('{0}\bin;{1}' -f $env:JAVA_HOME, $env:PATH); \
	Write-Host ('Updating PATH: {0}' -f $newPath); \
	setx /M PATH $newPath; \
	Write-Host 'Complete.'

# https://adoptopenjdk.net/upstream.html
# >
# > What are these binaries?
# >
# > These binaries are built by Red Hat on their infrastructure on behalf of the OpenJDK jdk8u and jdk11u projects. The binaries are created from the unmodified source code at OpenJDK. Although no formal support agreement is provided, please report any bugs you may find to https://bugs.java.com/.
# >
ENV JAVA_VERSION 11.0.11+9
ENV JAVA_URL https://github.com/AdoptOpenJDK/openjdk11-upstream-binaries/releases/download/jdk-11.0.11%2B9/OpenJDK11U-jdk_x64_windows_11.0.11_9.zip
# https://github.com/docker-library/openjdk/issues/320#issuecomment-494050246
# >
# > I am the OpenJDK 8 and 11 Updates OpenJDK project lead.
# > ...
# > While it is true that the OpenJDK Governing Board has not sanctioned those releases, they (or rather we, since I am a member) didn't sanction Oracle's OpenJDK releases either. As far as I am aware, the lead of an OpenJDK project is entitled to release binary builds, and there is clearly a need for them.
# >

RUN Write-Host ('Downloading {0} ...' -f $env:JAVA_URL); \
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
	Invoke-WebRequest -Uri $env:JAVA_URL -OutFile 'openjdk.zip'; \
# TODO signature? checksum?
	\
	Write-Host 'Expanding ...'; \
	New-Item -ItemType Directory -Path C:\temp | Out-Null; \
	Expand-Archive openjdk.zip -DestinationPath C:\temp; \
	Move-Item -Path C:\temp\* -Destination $env:JAVA_HOME; \
	Remove-Item C:\temp; \
	\
	Write-Host 'Removing ...'; \
	Remove-Item openjdk.zip -Force; \
	\
	Write-Host 'Verifying install ...'; \
	Write-Host '  javac --version'; javac --version; \
	Write-Host '  java --version'; java --version; \
	\
	Write-Host 'Complete.'

ENV EDB_VER 9.4.24
ENV EDB_REPO https://get.enterprisedb.com/postgresql

##### Use PowerShell for the installation
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

### Download EnterpriseDB and remove cruft
RUN $URL1 = $('{0}/postgresql-{1}-windows-x64-binaries.zip' -f $env:EDB_REPO,$env:EDB_VER) ; \
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; \
    Invoke-WebRequest -Uri $URL1 -OutFile 'C:\\EnterpriseDB.zip' ; \
    Expand-Archive 'C:\\EnterpriseDB.zip' -DestinationPath 'C:\\' ; \
    Remove-Item -Path 'C:\\EnterpriseDB.zip' ; \
    Remove-Item -Recurse -Force –Path 'C:\\pgsql\\doc' ; \
    Remove-Item -Recurse -Force –Path 'C:\\pgsql\\include' ; \
    Remove-Item -Recurse -Force –Path 'C:\\pgsql\\pgAdmin*' ; \
    Remove-Item -Recurse -Force –Path 'C:\\pgsql\\StackBuilder'

### Make the sample config easier to munge (and "correct by default")
RUN $SAMPLE_FILE = 'C:\\pgsql\\share\\postgresql.conf.sample' ; \
    $SAMPLE_CONF = Get-Content $SAMPLE_FILE ; \
    $SAMPLE_CONF = $SAMPLE_CONF -Replace '#listen_addresses = ''localhost''','listen_addresses = ''*''' ; \
    $SAMPLE_CONF | Set-Content $SAMPLE_FILE

### Install correct Visual C++ Redistributable Package
RUN if (($env:EDB_VER -like '9.*') -or ($env:EDB_VER -like '10.*')) { \
        Write-Host('Visual C++ 2013 Redistributable Package') ; \
        $URL2 = 'https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe' ; \
    } else { \
        Write-Host('Visual C++ 2017 Redistributable Package') ; \
        $URL2 = 'https://download.visualstudio.microsoft.com/download/pr/11100230/15ccb3f02745c7b206ad10373cbca89b/VC_redist.x64.exe' ; \
    } ; \
    Invoke-WebRequest -Uri $URL2 -OutFile 'C:\\vcredist.exe' ; \
    Start-Process 'C:\\vcredist.exe' -Wait \
        -ArgumentList @( \
            '/install', \
            '/passive', \
            '/norestart' \
        )

# Determine new files installed by VC Redist
# RUN Get-ChildItem -Path 'C:\\Windows\\System32' | Sort-Object -Property LastWriteTime | Select Name,LastWriteTime -First 25

# Copy relevant DLLs to PostgreSQL
RUN if (Test-Path 'C:\\windows\\system32\\msvcp120.dll') { \
        Write-Host('Visual C++ 2013 Redistributable Package') ; \
        Copy-Item 'C:\\windows\\system32\\msvcp120.dll' -Destination 'C:\\pgsql\\bin\\msvcp120.dll' ; \
        Copy-Item 'C:\\windows\\system32\\msvcr120.dll' -Destination 'C:\\pgsql\\bin\\msvcr120.dll' ; \
    } else { \
        Write-Host('Visual C++ 2017 Redistributable Package') ; \
        Copy-Item 'C:\\windows\\system32\\vcruntime140.dll' -Destination 'C:\\pgsql\\bin\\vcruntime140.dll' ; \
    }

#### In order to set system PATH, ContainerAdministrator must be used
USER ContainerAdministrator
RUN setx /M PATH "C:\\pgsql\\bin;%PATH%"
USER ContainerUser
ENV PGDATA "C:\\pgsql\\data"

COPY docker-entrypoint.cmd /
ENTRYPOINT ["C:\\docker-entrypoint.cmd"]

EXPOSE 5432

CMD ["echo READY"]