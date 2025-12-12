# proxyctl

终端代理管理脚本，用于管理 shell 环境变量中的代理设置。

## 安装

使用以下命令安装：

```bash
curl -fsSL https://raw.githubusercontent.com/MorvenCat/Proxyctl/main/install.sh | bash
```

## 使用

命令如下。

```bash
proxy set all 127.0.0.1 7890
proxy set http 127.0.0.1 7890
proxy set https 127.0.0.1 7890
proxy set socks5 127.0.0.1 7890
proxy on
proxy off
proxy status

```

## 卸载

使用以下命令卸载：

```bash
curl -fsSL https://raw.githubusercontent.com/MorvenCat/proxyctl/main/uninstall.sh | bash
```
