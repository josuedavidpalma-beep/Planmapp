$ErrorActionPreference = "Stop"

$jdkUrl = "https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.zip"
$installDir = "$env:USERPROFILE\.gemini\tools\java"
$zipPath = "$installDir\jdk.zip"

Write-Host "Creando directorio de instalacion: $installDir..."
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

Write-Host "Descargando Microsoft OpenJDK 17..."
Invoke-WebRequest -Uri $jdkUrl -OutFile $zipPath

Write-Host "Extrayendo JDK..."
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force

# Find the extracted folder name (it might be jdk-17.x.y...)
$extractedFolder = Get-ChildItem -Path $installDir -Directory | Where-Object { $_.Name -like "jdk-*" } | Select-Object -First 1
$javaHome = $extractedFolder.FullName

Write-Host "JDK extraido en: $javaHome"

# Set JAVA_HOME persistently
Write-Host "Configurando JAVA_HOME..."
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, [System.EnvironmentVariableTarget]::User)

# Add to PATH persistently
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
$binPath = "$javaHome\bin"

if ($currentPath -notlike "*$binPath*") {
    Write-Host "Agregando al PATH..."
    $newPath = "$currentPath;$binPath"
    [System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::User)
} else {
    Write-Host "Java ya esta en el PATH."
}

# Clean up zip
Remove-Item -Path $zipPath -Force

Write-Host "¡Instalacion completada! JAVA_HOME configurado."
Write-Host "Por favor, reinicia tu terminal o IDE para que los cambios surtan efecto."
