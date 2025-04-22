(traduzido pelo github copilot)
# Guacamole com docker compose
Esta é uma pequena documentação sobre como executar uma instância totalmente funcional do **Apache Guacamole (incubating)** com docker (docker compose). O objetivo deste projeto é facilitar o teste do Guacamole.

## Sobre o Guacamole
O Apache Guacamole (incubating) é um gateway de desktop remoto sem cliente. Ele suporta protocolos padrão como VNC, RDP e SSH. É chamado de "sem cliente" porque não são necessários plugins ou softwares de cliente. Graças ao HTML5, uma vez que o Guacamole está instalado em um servidor, tudo o que você precisa para acessar seus desktops é um navegador web.

Ele suporta RDP, SSH, Telnet e VNC e é o gateway HTML5 mais rápido que conheço. Confira a [página inicial](https://guacamole.incubator.apache.org/) do projeto para mais informações.

## Pré-requisitos
Você precisa de uma instalação funcional do **docker** e do **docker compose** em sua máquina.

## Início rápido
Clone o repositório GIT e inicie o Guacamole:

### Para Linux:
~~~bash
git clone "https://github.com/GabrielStange/guacamole-docker-compose.git"
cd guacamole-docker-compose
./prepare.sh
docker compose up -d
~~~

### Para Windows:
~~~powershell
git clone "https://github.com/GabrielStange/guacamole-docker-compose.git"
cd guacamole-docker-compose
.\prepare.ps1
docker compose up -d
~~~

Seu servidor Guacamole agora deve estar disponível em `https://ip do seu servidor:8443/`. O nome de usuário padrão é `guacadmin` com a senha `guacadmin`.

## Detalhes
Para entender alguns detalhes, vamos dar uma olhada mais de perto em partes do arquivo `docker-compose.yml`:

### Rede
A seguinte parte do docker-compose.yml criará uma rede com o nome `guacnetwork_compose` no modo `bridged`.
~~~python
...
# networks
# create a network 'guacnetwork_compose' in mode 'bridged'
networks:
  guacnetwork_compose:
    driver: bridge
...
~~~

### Serviços
#### guacd
A seguinte parte do docker-compose.yml criará o serviço guacd. O guacd é o coração do Guacamole, que carrega dinamicamente o suporte para protocolos de desktop remoto (chamados de "plugins de cliente") e os conecta a desktops remotos com base nas instruções recebidas do aplicativo web. O contêiner será chamado de `guacd_compose` com base na imagem docker `guacamole/guacd`, conectada à nossa rede criada anteriormente `guacnetwork_compose`. Além disso, mapeamos as duas pastas locais `./drive` e `./record` no contêiner. Podemos usá-las mais tarde para mapear unidades de usuário e armazenar gravações de sessões.

~~~python
...
services:
  # guacd
  guacd:
    container_name: guacd_compose
    image: guacamole/guacd
    networks:
      guacnetwork_compose:
    restart: always
    volumes:
    - ./drive:/drive:rw
    - ./record:/record:rw
...
~~~

#### PostgreSQL
A seguinte parte do docker-compose.yml criará uma instância do PostgreSQL usando a imagem oficial do docker. Esta imagem é altamente configurável usando variáveis de ambiente. Por exemplo, ela inicializará um banco de dados se um script de inicialização for encontrado na pasta `/docker-entrypoint-initdb.d` dentro da imagem. Como mapeamos a pasta local `./init` dentro do contêiner como `docker-entrypoint-initdb.d`, podemos inicializar o banco de dados para o Guacamole usando nosso próprio script (`./init/initdb.sql`). Você pode ler mais sobre os detalhes da imagem oficial do postgres [aqui](http://).

~~~python
...
  postgres:
    container_name: postgres_guacamole_compose
    environment:
      PGDATA: /var/lib/postgresql/data/guacamole
      POSTGRES_DB: guacamole_db
      POSTGRES_PASSWORD: EscolhaSuaSenhaAqui1234
      POSTGRES_USER: guacamole_user
    image: postgres
    networks:
      guacnetwork_compose:
    restart: always
    volumes:
    - ./init:/docker-entrypoint-initdb.d:ro
    - ./data:/var/lib/postgresql/data:rw
...
~~~

#### Guacamole
A seguinte parte do docker-compose.yml criará uma instância do Guacamole usando a imagem docker `guacamole` do Docker Hub. Ela também é altamente configurável usando variáveis de ambiente. Nesta configuração, ela está configurada para se conectar à instância do postgres criada anteriormente usando um nome de usuário, senha e o banco de dados `guacamole_db`. A porta 8080 é exposta apenas localmente! Anexaremos uma instância do nginx para torná-la pública no próximo passo.

~~~python
...
  guacamole:
    container_name: guacamole_compose
    depends_on:
    - guacd
    - postgres
    environment:
      GUACD_HOSTNAME: guacd
      POSTGRES_DATABASE: guacamole_db
      POSTGRES_HOSTNAME: postgres
      POSTGRES_PASSWORD: EscolhaSuaSenhaAqui1234
      POSTGRES_USER: guacamole_user
    image: guacamole/guacamole
    links:
    - guacd
    networks:
      guacnetwork_compose:
    ports:
    - 8080/tcp
    restart: always
...
~~~

#### nginx
A seguinte parte do docker-compose.yml criará uma instância do nginx que mapeia a porta pública 8443 para a porta interna 443. A porta interna 443 é então mapeada para o Guacamole usando o arquivo `./nginx/templates/guacamole.conf.template`. O contêiner usará o certificado autoassinado gerado anteriormente (`prepare.sh`) em `./nginx/ssl/` com `./nginx/ssl/self-ssl.key` e `./nginx/ssl/self.cert`.

~~~python
...
  # nginx
  nginx:
   container_name: nginx_guacamole_compose
   restart: always
   image: nginx
   volumes:
   - ./nginx/templates:/etc/nginx/templates:ro
   - ./nginx/ssl/self.cert:/etc/nginx/ssl/self.cert:ro
   - ./nginx/ssl/self-ssl.key:/etc/nginx/ssl/self-ssl.key:ro
   ports:
   - 8443:443
   links:
   - guacamole
   networks:
     guacnetwork_compose:
...
~~~

## prepare.sh / prepare.ps1
Para ambientes Linux, use o script `prepare.sh` para criar o arquivo de inicialização do banco de dados e os certificados autoassinados necessários.

Para ambientes Windows, use o script `prepare.ps1`, que foi adaptado para garantir a compatibilidade com sistemas Windows.

`prepare.sh`/`prepare.ps1` é um pequeno script que cria `./init/initdb.sql` baixando a imagem docker `guacamole/guacamole` e iniciando-a assim:

~~~bash
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgresql > ./init/initdb.sql
~~~

Ele cria o arquivo de inicialização necessário para o postgres.

`prepare.sh` também cria o certificado autoassinado `./nginx/ssl/self.cert` e a chave privada `./nginx/ssl/self-ssl.key`, que são usados pelo nginx para https.

## reset.sh / reset.ps1
Para redefinir tudo para o início, use `reset.sh` no Linux ou `reset.ps1` no Windows.

## WOL

Wake on LAN (WOL) não funciona e eu não corrigirei isso porque está além do escopo deste repositório. Mas [zukkie777](https://github.com/zukkie777), que também registrou [este problema](https://github.com/boschkundendienst/guacamole-docker-compose/issues/12), corrigiu. Você pode ler sobre isso na [lista de discussão do Guacamole](http://apache-guacamole-general-user-mailing-list.2363388.n4.nabble.com/How-to-docker-composer-for-WOL-td9164.html).

**Aviso**

Baixar e executar scripts da internet pode prejudicar seu computador. Certifique-se de verificar a origem dos scripts antes de executá-los!