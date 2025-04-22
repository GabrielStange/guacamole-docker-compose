# Parar e remover contêineres
Write-Host "Parando e removendo contêineres..."
docker-compose down

# Remover volumes do Docker
Write-Host "Removendo volumes do Docker..."
docker volume prune -f

# Remover arquivos temporários
$basePath = ".\"
Write-Host "Removendo arquivos temporários..."
Remove-Item -Recurse -Force -Path "$basePath\init\*" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "$basePath\record\*" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "$basePath\nginx\ssl\*" -ErrorAction SilentlyContinue

Write-Host "Reset concluído. Ambiente limpo."