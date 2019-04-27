#!/bin/bash
#-*- coding: utf-8 -*-
#
# Copyright (C) 2019 Unirede Soluções Corporativas
#  _   _       _              _
# | | | |_ __ (_)_ __ ___  __| | ___
# | | | | '_ \| | '__/ _ \/ _` |/ _ \
# | |_| | | | | | | |  __/ (_| |  __/
#  \___/|_| |_|_|_|  \___|\__,_|\___|
#
#+------------------------------------------------------------------------------+
# Description: Script de integração via SNMPTrap.
#
# Authors: Vinicius Murmann <vinicius.murmann@unirede.net>
#          Aecio Pires <aecio.pires@unirede.net>
#          Cezar Serafini <cezar.serafini@unirede.net>
# Date: 09-Abr-2019
#
# Tutorial de instalação:
#   1- Instale os pacotes abaixo no CentOS7.
#
# sudo yum install -y epel-release
# sudo yum install -y perl-Sys-Syslog snmptt net-snmp-perl net-snmp-utils net-snmp wget git
#
#   2- Crie o diretório /etc/snmp/scripts.
#   3- Salve o script em /etc/snmp/scripts com a permissão 755 para o usuário root
#   4- Edite o arquivo /etc/snmp/snmptrapd.conf e adicione as seguintes linhas
#
# authCommunity execute public
# traphandle 1.3.6.1.4.1.4130.9.1.60 /etc/snmp/scripts/snmptrapge_pulsenet_v2.sh
# traphandle 1.3.6.1.4.1.4130.9.1.70 /etc/snmp/scripts/snmptrapge_pulsenet_v2.sh
# traphandle 1.3.6.1.4.1.4130.9.1.1 /etc/snmp/scripts/snmptrapge_pulsenet_v2.sh
#
#
#   OBS.:
#   a) public => eh o nome da comunidade SNMP configurado no servidor de gerencia V2COM.
#      Pode alterar, caso o nome da comunidade seja diferente.
#   b) As OIDs 1.3.6.1.4.1.4130.9.1.60, 1.3.6.1.4.1.4130.9.1.70 e 1.3.6.1.4.1.4130.9.1.1 são
#      as que identificam as traps enviadas pelo equipamento de gerencia da GE-Pulsenet.
#
#   5- Reinicie o serviço snmptrapd com o seguinte comando.
#
#   sudo service snmptrapd restart
#
#   6- De acordo com o ambiente, altere o valor das variáveis:
#      INTEGRACAO
#      ZABBIX_PROTOCOL
#      ZABBIX_SERVER
#      ZABBIX_PROXY
#      ZABBIX_PORT
#      ZABBIX_USER
#      ZABBIX_PASS
#      PREFIX
#      DEFAULT_GROUP_1
#      DEFAULT_GROUP_2
#      DEFAULT_TEMPLATE
#      DEFAULT_PROXY
#
#   7- Acompanhe os arquivos de log definidos nas variáveis:
#   LOGFILE e LOGFILE_SENT
#
#+------------------------------------------------------------------------------+

# ATENÇÃO
# Altere o valor da variável DEBUG_ENABLE para true, caso queira ver mensagens
# de debug no arquivo LOGFILE_TMP.
# Por padrão, o valor é false, não exibe mensagens de debug.
DEBUG_ENABLE=false

###### LEITURA DAS VARBIDS DO TRAP ######################################
read hostname
read manager_ip
read uptime
read oid
read event
read trap_type
read key
read value
read host_client_name
read status
read description

##################################################################################

# CRIAÇÃO DO ARQUIVO TRAP PARA CONFERÊNCIA DOS DADOS
INTEGRACAO=ge_pulsenet
LOGDIR=/var/log/snmptrap/
LOGFILE=$LOGDIR/snmptrap$INTEGRACAO.log
LOGFILE_TMP=/tmp/$INTEGRACAO.log
LOGFILE_SENT=$LOGDIR/snmptrap$INTEGRACAO-sent.log
mkdir -p $LOGDIR

# Exibindo o debug, caso o valor da variavel DEBUG_ENABLE seja true
if $DEBUG_ENABLE ; then
  echo "[DEBUG] BEGIN_SCRIPT: `date +%Y%m%d-%H:%M:%S`" >> $LOGFILE_SENT
fi

# Log dos valores atribuídas as VARBINDs do snmptrap
echo "[INFO] VARIABLES_BEGIN" >> $LOGFILE
echo "[INFO] Valores recebidos  nao processadas das variaveis de trap - ordem em que sao recebidos pelo SNMPTrap" >> $LOGFILE
echo "`date` => Ordem 1 | $hostname => Ordem 2 | $manager_ip => Ordem 3 | $uptime => Ordem 4 | $oid => Ordem 5 | $event => Ordem 6 | $trap_type => Ordem 7 | $key => Ordem 8 | $value => Ordem 9 | $host_client_name => Ordem 10 | $status => Ordem 11 | $description => Ordem 12" >> $LOGFILE

####################################################################################
# PROCESSAMENTOS DAS VARBINS
####################################################################################

manager_ip=`echo $manager_ip | cut -d ":" -f 2 | sed "s/\]//g" | sed "s/\[//g" | sed "s/\ //g"`
host_client_name=`echo $host_client_name |cut -f2 -d' '`
oid=`echo $oid|cut -f2 -d' '`
trap_type=`echo $trap_type|cut -f2 -d' '`
item=`echo $key | cut -d ' ' -f 2-20 | sed "s/\"//g" | sed "s/\ //g"`
item2=`echo $value | cut -d ' ' -f 2-20 | sed "s/\"//g" | sed "s/\ //g"`
data=`echo $status | cut -d ' ' -f 2-30 | sed "s/\"//g" | sed "s/\ //g"`
description=`echo $description | cut -d ' ' -f 2-30 | sed "s/\"//g" | sed "s/\ //g"`
event=`echo $event|cut -f11 -d'.'`
trap_type=`echo $trap_type|cut -f2 -d'"'`
event=`echo $event|cut -f11 -d'.'`
trap_type=`echo $trap_type|cut -f4-20 -d'"'`
repetidora=`echo $host_client_name | sed "s/\"//g"`

echo "[INFO] Valores processados - ordem em que os valores ficaram apos o processamento" >> $LOGFILE
echo "`date` => Ordem 1 | $hostname => Ordem 2 | $manager_ip => Ordem 3 | $uptime => Ordem 4 | $oid => Ordem 5 | $event => Ordem 6 | $trap_type => Ordem 7 | $item => Ordem 8 | $item2 => Ordem 9 | $repetidora => Ordem 10 | $data => Ordem 11 | $description => Ordem 12 " >> $LOGFILE
echo "[INFO] VARIABLES_END" >> $LOGFILE

# CONEXAO API ZABBIX ##################################################################

# Prefixo que representa o nome da empresa do cliente.
PREFIX="EMB"

# Variáveis referentes a conexão com a API do Zabbix
# Mude de acordo com o ambiente
ZABBIX_PROTOCOL="http"
ZABBIX_SERVER=""
ZABBIX_USER=""
ZABBIX_PASS=""
API="$ZABBIX_PROTOCOL://$ZABBIX_SERVER/zabbix/api_jsonrpc.php"
HEADER='Content-Type:application/json'
ZABBIX_PROXY=""
ZABBIX_PORT="10051"
ZABBIX_SENDER="/usr/bin/zabbix_sender"
HOST=$manager_ip

# Por padrão, o host será cadastrado no grupo de ID: 3603
# Corresponde ao grupo:
DEFAULT_GROUP_1="3603"
# Corresponde ao grupo
DEFAULT_GROUP_2="2328"

# Por padrão, o host será associadao ao template de ID 30140
# Corresponde ao template: Template Pulsenet GE Traps
DEFAULT_TEMPLATE="30140"

# Cria os hosts no zabbix

# Por padrão, o host será associadao ao proxy de ID 10258
# Corresponde ao proxy: BASDR-ZXPR01
DEFAULT_PROXY="10258"

# O nome do host client eh uma das VARBINDS processada anteriormente
# Corresponde ao nome do servidor de gerencia SNMPTrap
if [ "$description" = "FATAL" ] ;then
  # O nome do host client estará em outra variavel porque o nome do host muda
  # de posicao quando a gerencia envia uma trap referente a um evento do tipo FATAL
  NAME=$(echo ${PREFIX}_${data})
  KEY=$(echo ${item2})
else
  NAME=$(echo ${PREFIX}_${repetidora})
  KEY=$(echo ${item})
fi


# O IP do host client eh uma das VARBINDS processada anteriormente
# Corresponde ao IP do servidor de gerencia SNMPTrap
IPADDRESS=$manager_ip


# Exibindo a ajuda do script
function help() {
  echo
  echo "$0 <host>"
  echo
  echo
}

# Fazendo login na API do Zabbix
function authenticate_api() {

  JSON="{
    \"jsonrpc\": \"2.0\",
    \"method\": \"user.login\",
    \"params\": {
        \"user\": \"$ZABBIX_USER\",
        \"password\": \"$ZABBIX_PASS\"
    },
    \"id\": 0}"

  curl -s -X POST -H "$HEADER" -d "$JSON" "$API" | cut -d '"' -f8

  # Exibindo o debug, caso o valor da variavel DEBUG_ENABLE seja true
  if $DEBUG_ENABLE ; then
    echo "[DEBUG_COMMAND] curl -s -X POST -H \"$HEADER\" -d \"$JSON\" \"$API\" | cut -d '\"' -f8" >> $LOGFILE_SENT
  fi
}

# Fazendo logout na API do Zabbix
function logout_api() {

  JSON="{
    \"jsonrpc\": \"2.0\",
    \"method\": \"user.logout\",
    \"params\": [],
    \"id\": 1,
    \"auth\": \"$AUTH_TOKEN\"}"

  curl -s -X POST -H "$HEADER" -d "$JSON" "$API" | cut -d '"' -f7 | cut -d':' -f2 | cut -d',' -f1

  # Exibindo o debug, caso o valor da variavel DEBUG_ENABLE seja true
  if $DEBUG_ENABLE ; then
    echo "[DEBUG_COMMAND] curl -s -X POST -H \"$HEADER\" -d \"$JSON\" \"$API\" | cut -d '\"' -f7 | cut -d':' -f2 | cut -d',' -f1" >> $LOGFILE_SENT
  fi
}

# Tentando obter o ID de um host cadastrado no Zabbix a partir de uma string
# informada na variavel NAME, criada anteriormente neste script.
function get_host_id() {

  JSON="{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.get\",
    \"params\": {
        \"output\": [ \"hostid\" ],
        \"filter\": {
            \"name\" : [ \"$NAME\" ]
        }
    },
    \"auth\": \"$AUTH_TOKEN\",
    \"id\": 2 }"

  curl -s -X POST -H "$HEADER" -d "$JSON" "$API" | cut -d '"' -f10

  # Exibindo o debug, caso o valor da variavel DEBUG_ENABLE seja true
  if $DEBUG_ENABLE ; then
    echo "[DEBUG_COMMAND] curl -s -X POST -H \"$HEADER\" -d \"$JSON\" \"$API\" | cut -d '\"' -f10" >> $LOGFILE_SENT
  fi

}

# Tentando obter o NOME de um host cadastrado no Zabbix a partir de uma string
# informada na variavel NAME, criada anteriormente neste script.
function get_name_id() {

  JSON="{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.get\",
    \"params\": {
        \"output\": [ \"name\" ],
        \"filter\": {
            \"name\" : [ \"$NAME\" ]
        }
    },
    \"auth\": \"$AUTH_TOKEN\",
    \"id\": 2 }"

  curl -s -X POST -H "$HEADER" -d "$JSON" "$API" | cut -d '"' -f14

  # Exibindo o debug, caso o valor da variavel DEBUG_ENABLE seja true
  if $DEBUG_ENABLE ; then
    echo "[DEBUG_COMMAND] curl -s -X POST -H \"$HEADER\" -d \"$JSON\" \"$API\" | cut -d '\"' -f14" >> $LOGFILE_SENT
  fi

}

# Tentando criar um host no Zabbix usando
# as variaveis NAME, IPhost_client_name, DEFAULT_GROUP_1, DEFAULT_GROUP_2, DEFAULT_TEMPLATE e DEFAULT_PROXY,
# criadas anteriormente neste script.
#
# O host será criado com o status monitorado e "NÃO em manutenção".
function create_host() {

  JSON="{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.create\",
    \"params\": {
        \"host\": \"$NAME\",
        \"status\": \"0\",
        \"interfaces\": [{
            \"type\": \"1\",
            \"main\": \"1\",
            \"useip\": \"1\",
            \"ip\": \"$IPADDRESS\",
            \"dns\": \"\",
            \"port\": \"10050\"
        }],
        \"groups\": [
            {\"groupid\": \"$DEFAULT_GROUP_1\" },
            {\"groupid\": \"$DEFAULT_GROUP_2\" }
        ],
        \"templates\": [{ \"templateid\": \"$DEFAULT_TEMPLATE\"}],
        \"proxy_hostid\": \"$DEFAULT_PROXY\",
        \"maintenance_status\": \"0\"
    },
    \"auth\": \"$AUTH_TOKEN\",
    \"id\": 2 }"

  curl -s -X POST -H "$HEADER" -d "$JSON" "$API" | cut -d '"' -f10

  # Exibindo o debug, caso o valor da variavel DEBUG_ENABLE seja true
  if $DEBUG_ENABLE ; then
     echo "[DEBUG_COMMAND] curl -s -X POST -H \"$HEADER\" -d \"$JSON\" \"$API\" | cut -d '\"' -f10" >> $LOGFILE_SENT
  fi
}

echo "[INFO] Enviando dados ao Zabbix ..." >> $LOGFILE_SENT

# Obtendo o token apos autenticação na API do Zabbix
AUTH_TOKEN=$(authenticate_api)

# Obtendo o ID do host cadastrado no Zabbix
HOSTID=$(get_host_id)

# Obtendo o nome do host cadastrado no Zabbix
NAMEID=$(get_name_id)

# Exibindo o debug, caso o valor da variavel DEBUG_ENABLE seja true
if $DEBUG_ENABLE ; then
  echo "[DEBUG] STRING_NAME_TO_SEARCH: $NAME" >> $LOGFILE_SENT
  echo "[DEBUG] API_URL: $API" >> $LOGFILE_SENT
  echo "[DEBUG] TOKEN: $AUTH_TOKEN" >> $LOGFILE_SENT
  echo "[DEBUG] HOSTID: $HOSTID" >> $LOGFILE_SENT
  echo "[DEBUG] HOSTNAME: $NAMEID" >> $LOGFILE_SENT
fi

## VERIFICA SE O HOST EXISTE NO ZABBIX ###############################################
if [ -z $HOSTID ] && [ -z $NAMEID ];then
  echo "[WARNING] Host: $NAME NAO esta cadastrado no Zabbix. Tentarei cadastra-lo usando a API do Zabbix." >> $LOGFILE_SENT
  # Obtendo o ID do host cadastrado no Zabbix
  NEW_HOSTID=$(create_host)
  echo "[INFO] Foi criado o host:$NAME com ID:$NEW_HOSTID." >> $LOGFILE_SENT
  /usr/sbin/zabbix_proxy -R config_cache_reload >> $LOGFILE_SENT
  sleep 3
  HOSTID=$NEW_HOSTID
fi

echo "[INFO] Host:$NAME ID:$HOSTID NAME:$NAMEID - ja cadastrado no Zabbix. Tentando atualizar as informacoes usando o ZABBIX SENDER." >> $LOGFILE_SENT
if [ "$description" = "FATAL" ] ;then
  if ! $ZABBIX_SENDER -z $ZABBIX_PROXY -s "$NAME" -k "$KEY" -o "$description"; then
   echo "[ERROR] Falha no envio para zabbix: $NAME - $KEY - $description " >> $LOGFILE_SENT
  fi
else
  if ! $ZABBIX_SENDER -z $ZABBIX_PROXY -s "$NAME" -k "$KEY" -o "$data"; then
   echo "[ERROR] Falha no envio para zabbix: $NAME - $KEY - $data " >> $LOGFILE_SENT
  fi
fi


# Fazendo logout na API do Zabbix
logout_api

# Exibindo o debug, caso o valor da variavel DEBUG_ENABLE seja true
if $DEBUG_ENABLE ; then
  echo "[DEBUG] END_SCRIPT: `date +%Y%m%d-%H:%M:%S`" >> $LOGFILE_SENT
fi
echo "`date` - FIM DO PROCESSO" >> $LOGFILE_SENT
exit

