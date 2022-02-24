
这篇随笔，是记录前几天在一次挖洞过程中学到的新的知识，在对目标进行渗透测试的过程中，发现目标站点存在[NTLM认证](https://doubleoctopus.com/security-wiki/protocol/nt-lan-manager/)，并且FUZZ之后确定存在弱口令。

因为平台使用的是弱口令，所以我很轻松的就登录到了页面中(没错挖洞有时候真的是靠运气)，并且找到了一个POST请求的注入点。

![image.png](../assets/2020-06-06-%E4%BD%BF%E7%94%A8SQLMAP%E5%9C%A8%E4%BD%BF%E7%94%A8NTLM%E8%AE%A4%E8%AF%81%E7%9A%84%E5%B9%B3%E5%8F%B0%E4%B8%AD%E8%BF%9B%E8%A1%8C%E6%B3%A8%E5%85%A5/image-e85274d015414b7d8eaa27ea6f9af9d8.png)

这是一个非常经典的POST请求，由于是实战环境，就把数据包内容打码了，我在使用SQLMAP对该请求进行注入时发现，SQLMAP一直显示一个401未经授权访问，从而发现在POST请求的参数中，存在着NTLM的验证信息(Cookie不知道为什么无效)。

在查询相关资料后，终于找到了一种有效的验证方法，首先，这里是[SQLMAP-NTLM脚本](https://github.com/mullender/python-ntlm)，需要安装它，才能够在目标拥有NTLM验证的情况下正常使用SQLMAP（运行环境：python2）

具体过程如下：

1. 将SQLMAP放置在Python2目录下(有环境变量的话无需)
2. 将下载的插件也放在Python2的目录下(有环境变量的话无需)，解压
3. 命令行进入SQLMAP插件的`python-ntlm-master\python26`目录下
4. 输入命令 （环境是python2）:`python setup.py install`

![image.png](../assets/2020-06-06-%E4%BD%BF%E7%94%A8SQLMAP%E5%9C%A8%E4%BD%BF%E7%94%A8NTLM%E8%AE%A4%E8%AF%81%E7%9A%84%E5%B9%B3%E5%8F%B0%E4%B8%AD%E8%BF%9B%E8%A1%8C%E6%B3%A8%E5%85%A5/image-523688cd70704b8e82a80369195e1750.png)

5. 将数据包复制到sqlmap目录下的文件中（自己新建一个）
6. 插件的参数如下：

![image.png](../assets/2020-06-06-%E4%BD%BF%E7%94%A8SQLMAP%E5%9C%A8%E4%BD%BF%E7%94%A8NTLM%E8%AE%A4%E8%AF%81%E7%9A%84%E5%B9%B3%E5%8F%B0%E4%B8%AD%E8%BF%9B%E8%A1%8C%E6%B3%A8%E5%85%A5/image-ec0461546a20455faaf4d9860d0b1b02.png)

 7. 由于我这里是NTLM，并且验证密码为弱口令：

![image.png](../assets/2020-06-06-%E4%BD%BF%E7%94%A8SQLMAP%E5%9C%A8%E4%BD%BF%E7%94%A8NTLM%E8%AE%A4%E8%AF%81%E7%9A%84%E5%B9%B3%E5%8F%B0%E4%B8%AD%E8%BF%9B%E8%A1%8C%E6%B3%A8%E5%85%A5/image-0396387c5d5c4e14b65196960bf423a6.png)

8. 运行结束，结果如下

![image.png](../assets/2020-06-06-%E4%BD%BF%E7%94%A8SQLMAP%E5%9C%A8%E4%BD%BF%E7%94%A8NTLM%E8%AE%A4%E8%AF%81%E7%9A%84%E5%B9%B3%E5%8F%B0%E4%B8%AD%E8%BF%9B%E8%A1%8C%E6%B3%A8%E5%85%A5/image-1e9a4238d8774aabae99c5fd0e4ee484.png)

![image.png](../assets/2020-06-06-%E4%BD%BF%E7%94%A8SQLMAP%E5%9C%A8%E4%BD%BF%E7%94%A8NTLM%E8%AE%A4%E8%AF%81%E7%9A%84%E5%B9%B3%E5%8F%B0%E4%B8%AD%E8%BF%9B%E8%A1%8C%E6%B3%A8%E5%85%A5/image-fd4b38ae0f8f46abb3171fc94df372dc.png)

