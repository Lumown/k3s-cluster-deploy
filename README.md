## Описание проекта

Проект описывает развертывание кластера K3s при помощи Terraform и его настройку при помощи Ansible.

Используемые технологии:
1. Гипервизор: Proxmox (имеет один публичный IP-адрес);
2. IaC: Ansible, Terraform (провайдер telmate/proxmox);
3. OS: Ubuntu 24.04 Cloud-init;
4. Оркестрация: K3s.


## Инструкция по запуску

1. Подготовка шаблона в Proxmox

```
if ! test -e ~/noble-server-cloudimg-amd64.qcow2; then
  curl https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img -o ~/noble-server-cloudimg-amd64.qcow2
fi
qm create 9999 --name "init" --memory 2048 --net0 virtio,bridge=vmbr0
qm disk import 9999 ~/noble-server-cloudimg-amd64.qcow2 local --format qcow2
qm set 9999 --scsihw virtio-scsi-pci --scsi0 local:9999/vm-9999-disk-0.qcow2
qm set 9999 --ide2 local:cloudinit
qm set 9999 --boot order=scsi0
qm set 9999 --serial0 socket --vga serial0
qm set 9999 --agent 1
qm template 9999
```

2. Развертывание инфраструктуры

```
cd terraform/
# Переименовать terraform.tfvars.example в terraform.tfvars и заполнить все поля в этом файле
terraform init
terraform apply
```

3. Настройка ОС и кластера
```
cd ansible
ansible-playbook -i hosts.ini k3s_setup.yml 
```

## Возникавшие проблемы

### 1. Изоляция сети ВМ

Для изоляции сети виртуальных машин необходимо было:
1. Создать новый интерфейс **vmbr0**, который будет выступать в качестве шлюза;
2. Прописать конфигурацию этого интерфейса в файле `/etc/network/interfaces`. Конфигурация представлена ниже.

  ```
auto vmbr0
iface vmbr0 inet static
        address 10.0.0.1/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0

        post-down iptables -t nat -F POSTROUTING
        post-down iptables -t filter -F FORWARD
        post-up /usr/local/bin/bridge_reload.sh

        # Включаем роутинг
        post-up echo 1 > /proc/sys/net/ipv4/ip_forward
        # Включаем NAT для подсети 10.0.0.0/24
        post-up iptables -t nat -A POSTROUTING -s '10.0.0.0/24' -o ens1 -j MASQUERADE
        # Разрешаем виртуалкам выходить наружу через мост
        post-up iptables -t filter -A FORWARD -i vmbr0 -j ACCEPT
        # Разрешаем ЛЮБОЙ входящий трафик, который является ОТВЕТОМ на запросы изнутри
        post-up iptables -t filter -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
  ```
  *Примечание*: в Proxmox по умолчанию в FORWARD установлен target ACCEPT, поэтому все будет работать даже если активно только правило для NAT. Два следующих правила нужны на случай изменения дефолтного target в цепочке FORWARD

### 2. Отсутствие связи с сетью ВМ после перезапуска сети на гипервизоре

При перезапуске сети на гипервизоре (`systemctl restart nerworking`) виртуальные машины теряли связь с гипервизором из-за того, что их tap-интерфейсы отсоединялись от моста vmbr0. Для решения этой проблемы был написан скрипт, автоматическое выполнение которого было прописано в конфигурации моста vmbr0 в `/etc/network/interfaces`. Скрипт представлен ниже.
```
for iface in $(ip link show | grep -oE 'tap[0-9]{3}i0'); do
        ip link set "$iface" master vmbr0
        ip link set "$iface" up
done
```

### 3. Версионирование Terraform-провайдеров

Proxmox использовался версии 9.2.9, в связи с чем провайдер Telmate должен был быть не ниже версии 3.0.2-rc04. 
Это необходимо, потому что более ранние версии Telmate требуют наличие у пользователя, под которым происходит подключение к Proxmox, привилегии VM.Monitor, в то время как в Proxmox 9+ эта привилегия была удалена

### 4. Идемпотентность и синтаксис

1. Таски "Install K3s server" и "Setup K3s Workers" каждый раз исполнялись заново. Для этого я добавил в `args` `creates: <путь_к_нужному_бинарнику>`. Так что, если этот файл уже есть на удаленном хосте, то задача не выполняется. 
2. `ansible-lint` ругался на отсутствие pipefail. Решение прочитал в официальной документации. 
3. Виртуальным машинам не назначался шлюз по умолчанию. Проблема была в пробеле, который стоял перед "gw=" в main.tf
