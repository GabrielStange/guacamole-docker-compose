(traduzido pelo github copilot)
# Guacamole com docker compose
Esta � uma pequena documenta��o sobre como executar uma inst�ncia totalmente funcional do **Apache Guacamole (incubating)** com docker (docker compose). O objetivo deste projeto � facilitar o teste do Guacamole.

## Sobre o Guacamole
O Apache Guacamole (incubating) � um gateway de desktop remoto sem cliente. Ele suporta protocolos padr�o como VNC, RDP e SSH. � chamado de "sem cliente" porque n�o s�o necess�rios plugins ou softwares de cliente. Gra�as ao HTML5, uma vez que o Guacamole est� instalado em um servidor, tudo o que voc� precisa para acessar seus desktops � um navegador web.

Ele suporta RDP, SSH, Telnet e VNC e � o gateway HTML5 mais r�pido que conhe�o. Confira a [p�gina inicial](https://guacamole.incubator.apache.org/) do projeto para mais informa��es.

## Pr�-requisitos
Voc� precisa de uma instala��o funcional do **docker** e do **docker compose** em sua m�quina.

## In�cio r�pido
Clone o reposit�rio GIT e inicie o Guacamole:

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

Seu servidor Guacamole agora deve estar dispon�vel em `https://ip do seu servidor:8443/`. O nome de usu�rio padr�o � `guacadmin` com a senha `guacadmin`.

## Detalhes
Para entender alguns detalhes, vamos dar uma olhada mais de perto em partes do arquivo `docker-compose.yml`:

### Rede
A seguinte parte do docker-compose.yml criar� uma rede com o nome `guacnetwork_compose` no modo `bridged`.
~~~python
...
# networks
# create a network 'guacnetwork_compose' in mode 'bridged'
networks:
  guacnetwork_compose:
    driver: bridge
...
~~~

### Servi�os
#### guacd
A seguinte parte do docker-compose.yml criar� o servi�o guacd. O guacd � o cora��o do Guacamole, que carrega dinamicamente o suporte para protocolos de desktop remoto (chamados de "plugins de cliente") e os conecta a desktops remotos com base nas instru��es recebidas do aplicativo web. O cont�iner ser� chamado de `guacd_compose` com base na imagem docker `guacamole/guacd`, conectada � nossa rede criada anteriormente `guacnetwork_compose`. Al�m disso, mapeamos as duas pastas locais `./drive` e `./record` no cont�iner. Podemos us�-las mais tarde para mapear unidades de usu�rio e armazenar grava��es de sess�es.

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
A seguinte parte do docker-compose.yml criar� uma inst�ncia do PostgreSQL usando a imagem oficial do docker. Esta imagem � altamente configur�vel usando vari�veis de ambiente. Por exemplo, ela inicializar� um banco de dados se um script de inicializa��o for encontrado na pasta `/docker-entrypoint-initdb.d` dentro da imagem. Como mapeamos a pasta local `./init` dentro do cont�iner como `docker-entrypoint-initdb.d`, podemos inicializar o banco de dados para o Guacamole usando nosso pr�prio script (`./init/initdb.sql`). Voc� pode ler mais sobre os detalhes da imagem oficial do postgres [aqui](http://).

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
A seguinte parte do docker-compose.yml criar� uma inst�ncia do Guacamole usando a imagem docker `guacamole` do Docker Hub. Ela tamb�m � altamente configur�vel usando vari�veis de ambiente. Nesta configura��o, ela est� configurada para se conectar � inst�ncia do postgres criada anteriormente usando um nome de usu�rio, senha e o banco de dados `guacamole_db`. A porta 8080 � exposta apenas localmente! Anexaremos uma inst�ncia do nginx para torn�-la p�blica no pr�ximo passo.

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
A seguinte parte do docker-compose.yml criar� uma inst�ncia do nginx que mapeia a porta p�blica 8443 para a porta interna 443. A porta interna 443 � ent�o mapeada para o Guacamole usando o arquivo `./nginx/templates/guacamole.conf.template`. O cont�iner usar� o certificado autoassinado gerado anteriormente (`prepare.sh`) em `./nginx/ssl/` com `./nginx/ssl/self-ssl.key` e `./nginx/ssl/self.cert`.

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
Para ambientes Linux, use o script `prepare.sh` para criar o arquivo de inicializa��o do banco de dados e os certificados autoassinados necess�rios.

Para ambientes Windows, use o script `prepare.ps1`, que foi adaptado para garantir a compatibilidade com sistemas Windows.

`prepare.sh`/`prepare.ps1` � um pequeno script que cria `./init/initdb.sql` baixando a imagem docker `guacamole/guacamole` e iniciando-a assim:

~~~bash
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgresql > ./init/initdb.sql
~~~

Ele cria o arquivo de inicializa��o necess�rio para o postgres.

`prepare.sh` tamb�m cria o certificado autoassinado `./nginx/ssl/self.cert` e a chave privada `./nginx/ssl/self-ssl.key`, que s�o usados pelo nginx para https.

## reset.sh / reset.ps1
Para redefinir tudo para o in�cio, use `reset.sh` no Linux ou `reset.ps1` no Windows.

## WOL

Wake on LAN (WOL) n�o funciona e eu n�o corrigirei isso porque est� al�m do escopo deste reposit�rio. Mas [zukkie777](https://github.com/zukkie777), que tamb�m registrou [este problema](https://github.com/boschkundendienst/guacamole-docker-compose/issues/12), corrigiu. Voc� pode ler sobre isso na [lista de discuss�o do Guacamole](http://apache-guacamole-general-user-mailing-list.2363388.n4.nabble.com/How-to-docker-composer-for-WOL-td9164.html).

**Aviso**

Baixar e executar scripts da internet pode prejudicar seu computador. Certifique-se de verificar a origem dos scripts antes de execut�-los!