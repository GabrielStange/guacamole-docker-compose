# Verificar se o Docker está em execução
Write-Host "Verificando se o Docker está em execução..."
try {
    $dockerCheck = docker version --format '{{.Server.Version}}' 2>$null
    if (-not $dockerCheck) {
        Write-Host "O Docker não está em execução ou não está aceitando comandos. Saindo do script."
        exit
    } else {
        Write-Host "O Docker está em execução. Versão da engine: $dockerCheck"
    }
} catch {
    Write-Host "Erro ao verificar o status do Docker. Certifique-se de que o Docker Desktop está instalado, configurado corretamente e que a engine está ativa."
    exit
}

# Criar diretórios necessários
Write-Host "Preparando diretórios..."
$basePath = ".\"
New-Item -ItemType Directory -Force -Path "$basePath\init" | Out-Null
New-Item -ItemType Directory -Force -Path "$basePath\nginx\ssl" | Out-Null
New-Item -ItemType Directory -Force -Path "$basePath\record" | Out-Null

# Definir permissões para os diretórios
Write-Host "Definindo permissões para os diretórios..."
## Diretório \init
$acl = Get-Acl "$basePath\init"
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
Set-Acl -Path "$basePath\init" -AclObject $acl
## Diretório \record
$acl = Get-Acl "$basePath\record"
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
Set-Acl -Path "$basePath\record" -AclObject $acl

# Gerar o arquivo initdb.sql
Write-Host "Gerando o arquivo initdb.sql..."
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgresql | Out-File -FilePath "$basePath\init\initdb.sql" -Encoding utf8

# Criar certificados SSL
Write-Host "Criando certificados SSL..."
$sslPath = "$basePath\nginx\ssl"
openssl req -nodes -newkey rsa:2048 -new -x509 -keyout "$sslPath\self-ssl.key" -out "$sslPath\self.cert" -subj "/C=DE/ST=BY/L=Hintertupfing/O=Dorfwirt/OU=Theke/CN=www.createyourown.domain/emailAddress=docker@createyourown.domain"

Write-Host "Você pode usar seus próprios certificados substituindo os arquivos self-ssl.key e self.cert no diretório nginx/ssl."
Write-Host "Preparação concluída."