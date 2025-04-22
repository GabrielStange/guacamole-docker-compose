# Parar e remover cont�ineres
Write-Host "Parando e removendo cont�ineres..."
docker-compose down

# Remover volumes do Docker
Write-Host "Removendo volumes do Docker..."
docker volume prune -f

# Remover arquivos tempor�rios
$basePath = ".\"
Write-Host "Removendo arquivos tempor�rios..."
Remove-Item -Recurse -Force -Path "$basePath\init\*" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "$basePath\record\*" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "$basePath\nginx\ssl\*" -ErrorAction SilentlyContinue

Write-Host "Reset conclu�do. Ambiente limpo."