# 浅识Kerberos & Windows 认证 [有错误?]



[**注意**] 该文章可能存在一些错误，如果你对Windows认证有一定了解，请直接查看 《[深入了解kerberos&windows认证攻击](./%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB)》

[**注意**] 如果对Windows认证没有了解，请简单看看，不必深究，因为大多数内容在 《[深入了解kerberos&windows认证攻击](./%E6%B7%B1%E5%85%A5%E4%BA%86%E8%A7%A3Kerberos&Windows%E8%AE%A4%E8%AF%81%E6%94%BB%E5%87%BB)》中均有详细讲解

# 一、本地认证





## 我的密码在哪里

本地存储在%SystemRoot%\system32\config\sam

在成功登录时会自动读取SAM文件中的密码，和我们输入的密码进行比对，如果相同，认证成功。



### NTLM Hash

NTLM Hash支持Net NTLM认证协议及本地认证，又称 NT Hash
长度为32位，由数字与字母组成。

windows本身不会存储用户的明文密码，会将用户明文密码加密后存储在SAM数据库中

爆破可使用python的nthash第三方库



### NTLM Hash产生过程

明文密码 -> hex -> Unicode -> MD4



### 本地认证流程

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-38e09d69ff1b4425bb4bea04663d72bf.png)



## LM Hash

产生过程

明文  ->  明文大写  ->  转为16进制，分两组，填充为14个字符，空余用0x00填补  -> 将密码分为两组7个字节的块  ->  转为比特流，不足56Bit左边补0  -> 转换为2进制  ->  将比特流7比特为一组，分8组，末尾加0  ->  将每组比特流转为16进制作为被加密的值  ->  使用DES加密，密钥为:"KGS!@#$%"，得到8个结果  ->  每个结果转换为16进制

因为密码不超过7个字节，后一半密码为固定的AA-D3-B4-35-B5-14-04-EE -> 连接两个DES加密字符串，构成LM Hash

存在问题:

1. DES加密的KEY为硬编码:"KGS!@#$%"
2. 密码不满7字节时填充0导致填充0的HASH为固定

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-61ba69c839e44800aa5d5ccda9a5d4b6.png)

# 二、Windows网络认证



## 工作组

工作组是一个逻辑上的网络环境(工作区)

工作组的机器之间无法互相建立一个完美的信任机制，只能点对点，没有信托机构。

工作组是没有中央身份验证的对等网络。工作组中的每台计算机都充当客户端和服务器。

当工作组中的用户想要访问另一用户的计算机甚至是共享资源（例如文件）时，他们需要在另一用户的计算机上创建其用户名和密码。工作组非常适合15台以下计算机的小型办公室网络，但是，对于拥有数百或数千用户的大型公司而言，它们并不是理想的选择。

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-69d7aaaac4624103b76e8315828a296a.png)

工作组的特点:

- 因为没有信托机构(中央身份验证)，所以需要在每台工作组的计算机中添加同样的用户和密码。



## 域

由于工作组没有信托机构，所以没有办法统一管理用户以及权限等，对于拥有数百或数千用户的大型公司而言，工作组并不是理想的选择。

在这样的环境中，我们需要建立一个客户端-服务器网络环境。在Windows中，这是通过设置域来实现的。

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-fd96f62f1248497da8a9614adeb50e07.png)

域可以确保更好的安全性，因为我们可以为不同的用户或用户组提供不同程度的权限。

此外，我们可以部署公司范围内的管理政策。如果用户要访问域中的另一台计算机，则无需在该计算机上创建另一个帐户。

用户的所有登录和访问请求均由运行AD(活动目录)的域控制器（DC）管理。DC是响应所有此类请求的集中式服务器，并且实际上是网络的安全网守。身份验证和授权均由DC完成。

- 域树
  例:caotang.org、ftp.caotang.org与user.ftp.caotang.org构成一个域树
- 域森林:是指由一个或多个没有形成连续名字空间的域树组成
  例:bg.caotang.org与ftp.caotang.org同在一个域林里
- 根域：域的根节点
  例:dc.n0b1ta.tk与tb.n0b1ta.tk这两个域森都由n0b1ta.tk这个域管理，那么n01bta.tk为他们的根域。

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-4f66754e8837483aa3b82f900a765a80.png)



### 域控

域控制器是运行在WindowsServer操作系统版本并安装了ActiveDirectory域服务的服务器。

说白了就是域内用来通过ActiveDirectory进行身份验证的服务器。
活动目录在下面呢👇



## AD-Active Directory（活动目录)



Active Directory用于存储有关网络上对象的信息，并使管理员和用户易于查找和使用此信息。

Active Directory使用结构化数据存储作为目录信息的逻辑层次结构(树形结构)的基础。

Active Directory目录服务将数据存储用于所有目录信息。该数据存储区通常称为目录。该目录包含有关对象的信息，例如用户，组，计算机，域，组织单位和安全策略。可以发布此信息以供用户和管理员使用。



### 目录数据存储

Active Directory目录服务将数据存储用于所有目录信息。该数据存储区通常称为目录。该目录包含有关对象的信息，例如用户，组，计算机，域，组织单位和安全策略。

该目录(AD)存储在域控制器(DC)上，并且可以由网络应用程序或服务访问。一个域可以具有一个或多个域控制器。每个域控制器都有其所在的整个域的目录副本(做冗余)。在对一个域控制器上的目录做更改时，AD的目录服务将会把更改的内容复制到域，域树或林中的其他域控制器(这个过程成为复制，其实就是同步)。

Active Directory使用四种不同的目录分区类型(域，配置，架构和应用程序数据)来存储和复制不同类型的数据。
域控制器之间复制的目录数据包括以下内容：

- 域数据
  域数据保存有关域内对象的信息,例:电子邮件联系人，用户和计算机帐户属性
- 配置数据
  配置数据描述了目录的拓扑。此配置数据包括所有域，树和林的列表以及域控制器和全局目录的位置。
- 模式数据
  模式是对对象和属性的定义类型，例:用户和计算机帐户，组，域，组织单位和安全策略。
- 申请资料
  存储在应用程序目录分区中的数据。

目录数据存储在域控制器上的Ntds.dit文件中



### Active Directory的安全性

Active Directory的安全性体现在访问控制及策略保护

Active Directory的安全性模块使管理员可以对所有对象设置很多的权限，这里就不一一的列举了，甚至可以设置禁止某个用户更换桌面。
详细见[AD的安全策略](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/executive-summary)

Active Directory的特点:

- Active Directory目录服务可以在多个DC(域控制器)上进行复制(同步)
- 目录数据存储在域控制器上的Ntds.dit文件中
- AD拥有访控的功能，安全性与Active Directory集成在一起。管理员可以通过AD管理整个网络中的目录数据和组织，授权的网络用户可以访问网络上任何地方的资源。

Active Directory还包括：

- 一组规则，即schema，用于定义目录中包含的对象和属性的类，这些对象的实例的约束和限制以及它们的名称格式。
- 一个全局catalog，包含有关目录中每个对象的信息。
- 一个查询和索引机制，以便对象及其属性可以发布，并通过网络用户或应用程序中。
- 一种复制(同步)服务，可在网络上分发目录数据。域中的所有域控制器都参与复制，并包含其域中所有目录信息的完整副本。
- 那什么是目录?类似这样:

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-47b25b33b2cb4e1793ca5a2c88a076e8.png)

或是这样:

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-2495891d927f47889868ec5065e8698b.png)

网络对象分为:用户、用户组、计算机、域、组织单位、及安全策略等。



## LDAP协议



详见[LDAP协议入门](https://zhuanlan.zhihu.com/p/147768058)



## NTLM协议



### 挑战(Challenge)/响应(Response)

NTML认证流程:
1.协商
查询目标系统的版本号，确定使用协议版本(LM、NTLMv1、NTLMv2)

2.质询

- 客户端向服务端发送用户信息(*用户名等)请求
- 服务器接收到请求，生成一个16位的 *** 随机数 *** ，被称为"Challenge"
- 服务端去SAM数据库文件中查询该客户端发送的用户信息是否允许登录。
- 如果是，使用客户端发送的用户信息对应的NTLM Hash(密文密码)加密Challenge，生成Challenge1（该Challenge1不会发送到客户端，*** 并存储在服务器的内存中 *** ）
- 同时，生成Challenge1后，将Challenge发送给客户端
- 客户端在接收到Challenge后，使用需要登录的账户的NTML Hash加密Challenge生成Response，将Response发送到服务端
- 服务端收到客户端的Response后，对比Challenge1与Response是否相等，如果相等，允许通过

```
Net NTML Hash = Challenge1 = NTML Hash(Challenge)
```

3.验证
验证即判断Response是否等于Challeng1

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-c6a6276d264e47ba885ff88650a17a28.png)

注:
用户密码不会在网络中明文传输

NTML v1与NTML v2的区别
Challage:v1的Challenge有8位，v2的Challenge有16位
Net-NTLM Hash:v1主要算法为DES，V2主要加密算法为HMAC-MD5

一般渗透测试工具:
Responder
smbexec



#### PTH(Pass The Hash哈希传递)

哈希传递就是在不需要账户明文密码的情况下完成认证的技术
解决了获取不到明文密码，又破解不了NTML Hash的问题

必要条件:

被认证主机能够访问到服务器

需要被传递认证的用户名

需要被传递认证用户的NTLM Hash

PTH原理:

伪造正常NTML认证，无需明文密码

工具:

Smbmap
CrackMapExec
Smbexec
MSF



## Kerberos协议

是一种网络认证协议，比NTML更加安全，有信托机构，该认证过程的实现不依赖于网络操作系统的认证，无需基于主机地址的信任，不要求网络上所有主机的物理安全， ***并假定网络上传送的数据包可以被任意地读取，修改和插入数据。*** (不怕中间人攻击)

Kerbroes的三个主体:

- Clinet
- Server
- KDC(密钥分发中心)



-  AD(account databbase)存储所有client的白名单，只有存在于白名单的client才能够申请到TGT - Authentication Service:为Client生成TGT的服务，校验客户端是否可信 - Tickent Granting Service:为Client生成某个服务的ticket

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-7584c3643c0849aa88d9358bef80cc26.png)

### kerberos简单认证流程:

#### 1.client向kerberos服务请求，希望获取访问server的权限。kerberos收到请求，首先判断client是否可信。也就是是否在白名单/黑名单中，这一步是由Authentication Service完成的:AS向AD发送请求，去验证该client是否在白名单/黑名单中。AD收到请求，如果该client存在于白名单中，将认证成功的消息返回给AS。AS收到后，Kerberos生成TGT发送给client。

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-4e96890a9194479ea19957e938df3560.png)

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-a40d437a9c154090bce1f2a6fbd380c9.png)

👆在第一步请求认证过程中，客户端首先会发送一个 ***KRB_AS_REQ*** 请求,该请求中包括:

- Pre-authentication data:
  `一个被用户名对应密码HASH加密的时间戳，用于KDC验证客户端身份`
  注:以下所有内容中所提到的时间戳，都是kerberos对安全的考虑: ***网络中所有的数据包均是可修改的*** 的这种前提下，防止数据遭到篡改，设定的时间戳，超出当前时间一定范围的时间戳将不做处理，认证失败。
- Client Info:
  `包含客户端的基础信息，例如计算机名，用户名，地址等`
- Server Info
  `客户端需要请求服务的TGS的相关信息`

KDC服务器在收到KRB_AS_REQ请求后，会使用Client info中的信息在AD(account database)中查找该用户是否可信。(AS进行此工作)

若可信，查找AD中用户名对应的 NTML HASH，再使用HASH解密Per-authentication data中的时间戳，验证时间戳的可用性。

验证成功后，生成一个随机的session key,再使用用户名对应的NTML HASH加密该session key。

随后验证该客户端是否有Server Info中请求的服务的访问权限，如果有，生成一个该服务的TGT,然后使用KDC特殊用户(krbtgt用户)的NTML HASH加密TGT，以备后续与TGS通信。

TGT中加密的内容如下图所示:

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-2b3eae1897e7453fa555a459550c8a0c.png)

👆在第一步的响应认证过程中，KDC返回一个 ***KRB_AS_REP*** 响应，其中包括:

- 一个使用客户端用户对应NTML HASH加密的随机Session Key
- 一个使用KDC Hash加密的TGT
  TGT的内容包括:
  随机的Session Key
  客户端名称
  TGT到期时间

注:客户端并没有KDC特殊用户(krbtgt用户)的NTML HASH，所以无法解密TGT，但是它可以解密Session Key与TGS服务通信。



#### 2.client收到了TGT后，将TGT附带在请求中去请求kerberos，去向kerberos获取访问server的权限。kerberos得到请求后通过client消息中的TGT，判断出了client拥有这个权限，返回消息给了client访问指定server服务的权限ticket。

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-0c62225c67fc426ba5a41e08e2f14f8a.png)

👆在第二部与TGS通信的请求过程中，客户端向TGS发送带有以下内容的请求包：

- TGT(来源于第一步中KDC返回的TGT)
- 使用Client HASH解密出的Session Key加密的Client Info与时间戳
- Client Info
- Server Info

TGS收到请求后，做以下操作:

- 使用KDC特殊用户(krbtgt用户)的HASH解密TGT

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-3263405d9c61468f836905a954c51eed.png)

注:因为TGS无Session Key，但是TGT中有，TGS又有KDC特殊用户(krbtgt用户)的HASH，所以先解密TGT，获得Session Key后再解Session Key加密的内容。

在解密完Session Key加密的内容后，验证时间戳是否正常，正常则继续。

在验证完时间戳后，比对Session Key加密的Client info是否和未加密传输的Client Info一致，如果一致，认证通过。

与此同时TGS去验证客户端是否拥有Server info中对应服务的权限，如果有，认证通过。

在通过之后，TGS向客户端发送一个数据包，该数据包有以下内容:

- 使用随机Session Key加密的Server Session Key(某个对应服务的随机Session Key，用于客户端与服务端通信)
- 使用Server Hash(Server Info中的服务器名出的对应服务端的NTML HASH)加密的Ticket(用于访问服务端的票据)

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-bc4c8856e9ac4bfa83d5c8a165958e4a.png)

👆Ticket中有以下内容

- Server Session Key
- 客户端信息
- 票据到期时间

注:因为客户端没有Server Hash所以无法解密Ticket，但是他有Session Key，所以可以解密Server Session Key

在第二步完成后，客户端已经不需要与KDC通信，只需要与对应服务的服务器通信了。



#### 3.client得到ticket后，终于可以成功访问server。但该ticket只是针对这个server，其他server需要向TGS申请

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-e3e7bd4b98424073991271f8a67e18ee.png)

👆首先客户端向对应服务的Server发送一个 ***KRB_AP_REQ*** 请求，其中包括:

- 从KDC的TGS中获取到的Ticket
- 由Server Session Key加密的Client info 与时间戳

继续看一下ticket的构成:

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-bc4c8856e9ac4bfa83d5c8a165958e4a-163764951082422.png)

由于Server并没有可以用于解密客户端信息与时间戳的Server Session Key，但是他拥有自身的Server NTML HASH，而Ticket中又存在可以解密上诉的Server Session Key，所以先解密Ticket。

Server通过自身HASH解密Ticket获得Server Session Key与客户端信息、票据到期时间。

再使用解密获得的Server Session Key去解密Client Info和时间戳。

对比Ticket中的Client info是否符合Server Session Key加密的Client info和时间戳是否合规，如果通过，则认证通过。

注:票据到期时间一定要大于当前时间，否则失效。
Kerberos认证会调用其他协议，例如:

- KRBS
- DCERPC
- SMB
- LDAP

到此，认证完成。



### 白银票据

> 说白了白银票据就是伪造Ticket

特点:

- 不需要与KDC进行交互
- 需要目标服务的Server NTML Hash(计算机对应Hash，加入域时会生成)
  该服务的NTML Hash在加入域时自动生成，并且添加进AD中。

如果理解了Kerberos加密，则极好理解白银票据与黄金票据源里，下面看一下在kerberos中第二步的Ticket。

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-bc4c8856e9ac4bfa83d5c8a165958e4a-163764963883626.png)

和第三步验证的内容

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-e3e7bd4b98424073991271f8a67e18ee-163764967492628.png)

在第三步认证中的Ticket的组成:

Ticket=Server Hash(Server Session Key+Client info+End Time)
当拥有Server Hash时，就可以伪造一个不经过KDC认证的一个Ticket

***PS:Server Session Key在未发送Ticket之前，服务器是不知道Server Session Key的。所以直接在Ticket伪造Server Session Key即可***

PS:客户端获得的票据会保存在内存中，可以使用工具读取，例如mimikatz

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-bc4c8856e9ac4bfa83d5c8a165958e4a-163764972795530.png)

白银票据只能针对Server Hash对应的服务器。

工具:mimikatz、wsf

白银票据无法生成对应域内所有服务器的票据，只能针对服务器上的某些服务去伪造，列表如下

DCSync用于域同步，如果拿到域控Hash的话，可以导出所有网络账户信息。

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-17211f5ca4354ccf97f8fc1e962744dd.png)



### 黄金票据

黄金票据特点:

- 需要与DC通信
- 需要KDC hash(krbtgt用户的hash)

可以伪造TGT

![image.png](../assets/2021-01-20-%E6%B5%85%E8%AF%86Kerberos&windows%E8%AE%A4%E8%AF%81/image-3263405d9c61468f836905a954c51eed-163764983077633.png)

只要伪造了TGT，后续过程中可以伪造任何东西。(在第二部认证过程中，KDC是先解开TGT才可以获取Session Key解密其他内容的。)

工具:mimikatz、wsf

PS:通过不断伪造TGT可以控制所有域内主机



## Windows Access Token

Windows Token其实也叫做Access Token，它是一个描述进程或线程安全上下文的一个对象。
不同的用户登录计算机后，都会生成一个Access Token，这个Token在用户创建进程或者线程时会被拷贝使用(例如用户打开了个软件，就会将access token拷贝使用于这个软件)，这就解释了A用户创建一个进程而该进程没有B用户的权限。

Access Token分为两种(主令牌、模拟令牌)

一般情况下，用户双击允许一个程序，都会拷贝"explorer.exe"的Access Token。

当用户 ***注销*** 后，系统会将主令牌切换为模拟令牌，不会将令牌清除，只有在重启机器后才会清除。

Windows Access Token组成

- 用户账户的安全标识符(SID)
- 用户所属的组的SID
- 用于标识当前登录会话的登录SID
- 用户或用户组所拥有的权限列表
- 所有者SID
- 主要组的SID
- 访问控制列表
- 访问令牌的来源
- 令牌是主要令牌还是模拟令牌
- 限制SID的可选列表
- 目前的模拟等级
- 其他统计数据

其余的内容目前不涉及内网渗透，所以只讲解SID
SID是一个唯一的字符串，可以代表一个账户、一个用户组，或者是一次登录。通常有一个SID固定列表。例如Everyone，默认拥有[固定的SID](https://docs.microsoft.com/zh-cn/windows/win32/secauthz/well-known-sids)

SID的表现形式:

- 域SID-用户ID
- 计算机SID-用户ID
- SID列表会存储在域控的AD或者计算机本地账户SAM数据库中

Windows Access Token产生过程

- 每个进程创建时都会根据登录会话权限由LSA分配一个Token(如果创建进程时自己指定了Token，LSA会使用指定的Token,否则使用父进程Token的一份拷贝)



### Windows Access Token令牌伪造

在用户注销后，系统将会使主令牌切换为模拟令牌，不会将令牌清除，只有在重启机器后才会清除。

可以使用一些工具查看目前系统上存在的模拟令牌(需要system权限)

- Incognito
- Powershell - Invoke-TokenManipulation.ps1
- Cobalt Strlike - steal_token
- ···

使用提取出的令牌可以伪造令牌用户的权限以及身份。

关于Access Token的详细内容可以查看[MS官方文档](https://docs.microsoft.com/zh-cn/windows/win32/secauthz/access-tokens)



## 应用Access Key/Token

部份云平台或者其他应用，为了二次开发方便，会生成Token对特定资源进行访问，同城基于云的应用程序，使用泄露的Token可以直接访问指定应用。

例如[阿里云Access Key](https://api.aliyun.com/)，甚至可以影响到主机开关机。

具体请查看各应用的官方文档



## 扩展知识点

域渗透技术/思路，SPN扫描，红蓝对抗
https://lolbas-project.github.io/
https://gtfobins.github.io/
https://github.com/yeyintminthuhtut/Awesome-Red-Teaming
