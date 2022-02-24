# Active Directory域森林以及信任问题的学习



[**注意:**] 文章中的工具来自[PowerSploit](https://github.com/PowerShellMafia/PowerSploit)

> 全文约一万三千字，预计阅读时间1小时20分钟



## 什么是森林(Forests)

在之前的文章中有提到过[森林](https://docs.microsoft.com/en-us/windows/win32/ad/forests)这个词，在这里简单描述一下

> 森林是一组**不构成连续命名空间**的一个或多个域树。 林中所有树共享一个通用架构、配置和全局目录。 给定林中所有树都根据可传递的分层 Kerberos 信任关系交换信任。 与树不同，林不需要不同的名称。 林作为成员树识别的一组交叉引用对象和 Kerberos 信任关系存在。
>
> 出于 Kerberos 信任的目的，林中的树构成了层次结构;信任树根目录的树名引用给定的林。
>
> **在只有一个域的组织中，该域也构成了整个林**

![image-20220224125159068](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125159068.png)



<center>非连续命名空间森林</center>

上图中的非连续命名空间森林需要手动建立林信任，而下面的contoso.local则不需要，因为contoso.local的信任是自动建立的

众所周知Kerberos与Active Directory均是基于DNS的，因为它允许为管理目的创建子域。

例如，公司可以有一个名为 contoso.local 的根域，然后是不同（通常是大）部门的子域，例如 it.contoso.local 或 hr.contoso.local，在下方的示例中，web.it.contoso.local相对于hr.contoso.local就是非连续命名空间的域树，也就是域林，该林的名称与树的根域的名称相同。

**在一些翻译中，容易翻译为森林和林两种，但是两种翻译实际都为英文`Forests`，不存在区别**

```
              contoso.local
                    |
            .-------'--------.
            |                |
            |                |
     it.contoso.local hr.contoso.local
            | 
            |
            |
  webs.it.contoso.local
```

<center>contoso.local 域森林</center>



在森林中，每个域都有自己的AD数据库和自己的域控制器。但是，林中域的用户也可以访问林中的其他域

这意味着，即使域可以是自治的，无需与其他域交互，从安全角度来看，它也不是孤立的，因为正如我们将看到的，来自同一域的用户可以访问同一域中其他域的资源（默认）。但是，默认情况下，一个林的用户无法访问其他林的资源因此可以提供安全隔离的逻辑结构就是林。



## 功能模式

简单来说，域控的系统版本一定要等于或高于该域/林的功能模式

例如:一个具有Windows 2012模式的域/林，DC的版本最低是 Windows Server 2012

不同的功能模式中，能够使用的域功能也不一样，例如:`受保护的用户组` 需要 Windows2012R2 模式

更多关于功能模式的内容请看[微软官方文档](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/564dc969-6db3-49b3-891a-f2f8d0a68a7f)



## 信任



关于信任的内容，推荐阅读《[Attacking Active Directory: 0 to 0.9](https://zer1t0.gitlab.io/posts/attacking_ad/#trusts)》，这里只讲一些关键点

还有一份长篇文章，对域和森林的信任讲解非常详细，它就是微软的《[How Domain and Forest Trusts Work](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc773178(v=ws.10)?redirectedfrom=MSDN)》

**信任是有方向的,且信任方向与访问方向相反，举个例子，A信任B，但是B不信任A，那么B可以访问A，但是A不能访问B**

信任还分为**出站信任**和**入站信任**

当出站信任和入站信任同时存在时，则为**双向信任关系**(互相信任)

```
 (trusting)         trusts        (trusted)
  Domain A  -------------------->  Domain B
       outgoing               incoming
       outbound               inbound
                    access
            <--------------------
```



使用` nltest /domain_trusts `查看域信任

```powershell
PS C:\Users\Anakin> nltest /domain_trusts
List of domain trusts:
    0: CONTOSO contoso.local (NT 5) (Direct Outbound) ( Attr: foresttrans )
    1: ITPOKEMON it.poke.mon (NT 5) (Forest: 2) (Direct Outbound) (Direct Inbound) ( Attr: withinforest )
    2: POKEMON poke.mon (NT 5) (Forest Tree Root) (Primary Domain) (Native)
The command completed successfully
```

<center>poke.mon 域的信任</center>

在这里我们可以看到我们当前的域是 poke.mon（由于（主域）属性）并且有几个信任。 contoso.local 的出站信任表明其用户可以访问我们的域 poke.mon。此外，还有第二个双向信任 it.poke.mon，它是 poke.mon 的子域，它位于同一个林中

```powershell
PS C:\Users\Anakin> nltest /domain_trusts
List of domain trusts:
    0: POKEMON poke.mon (NT 5) (Direct Inbound) ( Attr: foresttrans )
    1: CONTOSO contoso.local (NT 5) (Forest Tree Root) (Primary Domain) (Native)
The command completed successfully
```

<center>contoso.local 的信任</center>

检查 contoso.local 的信任，我们可以看到来自 poke.mon 的入站连接，这与之前的信息一致。因此 contoso.local 的用户可以访问 poke.mon

### 信托组件

![image-20220224125303976](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125303976.png)



- NTLM Protocol (Msv1_0.dll)

  - NTLM认证协议依赖于域控制器上的Net Logon服务来获取客户认证和授权信息。该协议对不使用Kerberos认证的客户进行认证。NTLM使用信任在域之间传递认证请求。

- Kerberos Protocol (Kerberos.dll)

  - Kerberos V5认证协议依赖于域控制器上的Net Logon服务以获得客户认证和授权信息。Kerberos协议连接到在线密钥分发中心（KDC）和活动目录账户存储，以获得会话票据。Kerberos协议还使用信任来进行跨领域的票证授予服务（TGS），并通过Net Logon验证特权属性证书（PAC）。Kerberos协议只对非Windows品牌的操作系统Kerberos领域（如MIT Kerberos领域）进行跨领域认证，并且这种跨领域认证不需要与Net Logon服务交互。

- Net Logon (Netlogon.dll)

  - 信任的建立和管理 - **Net Logon帮助维护信任密码**，收集信任信息，并通过与LSA进程和TDO的交互来验证信任
  - 认证 - 通过安全通道向域控制器提供用户凭证，并返回用户的域SID和用户权限
  - **域控制器定位** - 帮助寻找或定位一个域中或跨域的域控制器。
  - 通过验证 - 其他域中用户的凭证由Net Logon处理。当信任域需要验证一个用户的身份时，它通过Net Logon将用户的凭证传递给信任域进行验证。
  - **特权属性证书（PAC）验证** - 当使用Kerberos协议进行验证的服务器需要验证service ticket据中的PAC时，Net Logon将PAC通过安全通道发送到其域控制器进行验证。

- LSA (Lsasrv.dll)

  - 本地安全局（LSA）是一个受保护的子系统，它维护系统中本地安全的所有方面的信息（统称为本地安全策略），并提供各种服务，用于名称和标识符之间的转换。**LSA负责检查受信任或不信任域中的服务所提出的所有会话票的有效性。**

- Trusted Domain Object(TDO)

  - TDO中包含的信息可能会有所不同，这取决于TDO是由域信任还是由森林信任创建的。当一个域信任被创建时，诸如DNS域名、域SID、信任类型、信任转换性和互惠域名等属性在TDO中被表示。**森林信任TDO存储额外的属性，以识别来自伙伴森林的所有受信任的命名空间。这些属性包括域名树名称、用户主体名称（UPN）后缀、服务主体名称（SPN）后缀和安全ID（SID）名称空间。**
  - **因为信任以TDO的形式存储在活动目录中，所以Windows林中的所有域都知道在整个森林中存在的信任关系**

- TDO Passwords

  - 信任关系中的两个域共享一个密码，该密码存储在活动目录的TDO对象中。作为账户维护过程的一部分，**每隔30天，信任的域控制器会改变存储在TDO中的密码**。
  -  TDO 对象的 OldPassword 字段将在修改密码后设置为修改前的 NewPassword 字段，该操作是为了在DC不同步时恢复密码，**旧的、存储的密码可以通过安全通道使用**，这就是为什么**信任账户和krbgtg账户都需要修改两次以上密码才能防范攻击**

  

  


### 信任传递性

信任分为`可传递`和`不可传递`的，不可传递信任只能由信任的双方使用，即信任方和受信任方。而可传递信任可以充当桥梁并用于与可传递信任连接的域所连接的其他域

```
      (trusting)   trusts   (trusted)  (trusting)   trusts   (trusted)
  Domain A  ------------------->  Domain B --------------------> Domain C
                    access                          access
            <-------------------           <--------------------
```



例如，如果域 A 和域 B 之间的信任是可传递的，那么域 C 的用户可以通过遍历这两个信任来访问域 A。如果域 A --> 域 B 信任是不可传递的，则域 C 用户无法访问域 A，但域 B 用户可以



因此，对于同一个林中的域，所有同一域的域用户都可以访问同一域的其他子域，因为**当一个新的子域被创建时，在新的子域和父域之间会自动创建一个双向的、传递性的信任。**这样，林中的任何域都可以遍历所需的信任来访问同一林中的其他域

```
              contoso.local
               ^  v   v  ^  
          .----'  |   |  '----.
          |  .----'   '----.  |
          ^  v             v  ^
     it.contoso.local hr.contoso.local
          ^  v 
          |  |
          ^  v
  webs.it.contoso.local
```

但此时如果出现pokemon.local，并且没有建立可传递的林信任，那么pokemon.local和contoso.local将不可互相访问或不可传递信任

因此，要访问 hr.contoso.local 的计算机，webs.it.contoso.local 的用户必须遍历三个信任

**默认情况下，同一域中的父子域自动建立可传递的双向信任关系**

**信任在认知中被分为林内信任和林间信任**



### 信任类型

在Active Directory中，有几个不同用途的[信任类型](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-r2-and-2008/cc730798(v=ws.10)#trust-types)

- **Parent-Child**:父子信任，在父域与其子域之间创建的默认信任
- **Tree-root** : 树根信任，当你在森林中添加一个新的**域树**时，就建立了树根信任。**它只能在同一林的两棵树的根部之间建立，且必须是可传递和双向的**，但是一般不会遇见
- **Forest**:林信任，在森林之间共享资源的信任。这样，林中的任何域都可以访问其他林中的任何域（如果信任的方向和传递性允许的话，需要手动设置）**林信任只能在不同林的两个根域之间创建**,**森林信任只能在两个森林之间创建，不能隐含地扩展到第三个森林。**例如,A和B双向信任，B和C双向信任，但是A传递不能访问C
- **External**:外部信任，连接到不受信任林中特定域的信任,**默认执行最严格的SID Filter**，**它是不可传递的**
- **Realm**:领域,连接Active Directory和非Windows域(例如linux)的特殊信任，Kerberos中也使用该名词,**它只被 Kerberos V5 认证协议使用。它不被 NTLM 或其它认证协议所使用**
- **Shortcut**:快捷方式信任，当森林中的两个域经常通信但不直接连接时，您可以通过创建直接快捷方式信任来避免跳过许多信任，避免遍历信任造成大量的网络流量



### 信任密钥与信任账户

在创建林信任的时候，会在AD数据库中创建一个信任账户($结尾)，信任账户以目标林的根域名作为名称。

例如poke.mon域的信任账户为"POKEMON$"

且信任账户只存储在受信域的AD数据库中。

例如，onebit.lab域与poke.mon域双向信任，那么POKEMON$这个信任账户将会存储在onebit.lab的AD数据库中，ONEBITLAB$会存储在poke.mon的AD数据库中

```
PS C:\> Get-ADUser  -LDAPFilter "(SamAccountName=*$)" | select SamAccountName

SamAccountName
--------------
POKEMON$
```

<center>列出信任账户</center>



**信任密钥** 来自信任账户的NT hash，它与机器账户的NT hash一样，是随机且定时修改的

从技术上讲，当使用林信任时，请求域的域控制器与目标域（或中间域）的域控制器之间存在通信

通信的方式因所使用的协议（可能是 NTLM、Kerberos 等）而异，但无论如何，域控制器都需要共享密钥以确保通信安全。此密钥称为信任密钥，它是在建立信任时创建的。

**因为目标域的域控中没有保存请求域的数据库，所以才会使用到信任密钥**



## SID filter



关于SID filter，Dirk-jan Mollema 对它已经进行了深入的讲解，请看[这篇文章](https://dirkjanm.io/active-directory-forest-trusts-part-one-how-does-sid-filtering-work/#golden-tickets-and-sid-filtering)，我只划出了一些重点

首先，一般跨域林请求会产生三张票据

- 一张自身域的TGT，使用该域krbtgt账户加密
- 一张目标域的TGT，使用信任账户的NT hash加密
- 一张目标域服务的ST



**域本地组是唯一可以包含来自其他林的安全主体的组**



**林信任默认开启SID filter**

SID filter 会过滤票据中的这些SID

- 过滤任何全局组

- 过滤任何RID在500到1000之间的组
- 不属于原有域的SID
- 过滤不存在的SID



SID Filter 不会过滤掉

- 原有域存在通用组(伪造的SID，用户不存在该组中)



**但如果域信任有`TREAT_AS_EXTERNAL`标识**

> *如果设置该位，则该跨林信任将被视为用于SID滤波的目的的外部信任。跨林信托比外部信任更严格地过滤。此属性放松了那些跨林信托相当于外部信任。有关如何过滤每个信任类型的详细信息，请参阅[[MS-PAC]第4.1.2.2节](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-pac/55fc19f2-55ba-4251-8a6a-103dd7c66280?redirectedfrom=MSDN)*



**此属性将那些跨林信任放松为等同于外部信任。**



#### 一些附加的内容



当用户的 TGT 通过引用呈现给新域(跨领域TGT)时，该 TGT 包含特权属性证书 (PAC)，PAC中包含用户的安全标识符 (SID)、他们所在组的SID以及任何其他内容存在于sidHistory 字段中（即ExtraSids 字段）。 PAC中的该安全标识信息由信任域解析和分析，并根据信任的类型执行各种过滤。

作为安全保护，信任域在各种情况下都会拒绝匹配特定模式的 SID(比如500-1000RID)。 SID 过滤旨在阻止在受信任域/林中具有提升凭据的恶意用户控制信任域/林。这也在 Microsoft 的“[信任的安全注意事项](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc755321(v=ws.10)?redirectedfrom=MSDN)”文档中进行了描述。

有一组SID被设置为 "AlwaysFilter"，意味着它们总是被信任域过滤掉，无论信任类型如何。我们感兴趣的主要SID，"企业管理员"（S-1-5-21-<Domain>-519），即允许我们执行sidHistory-hopping攻击的那个，被设置为 "ForestSpecific "进行过滤。正如微软所描述的，"ForestSpecific规则是针对那些永远不允许出现在来自森林外或来自已被标记为QuarantinedWithinForest的域的PAC中的SID，除非它属于该域。" 这再次解释了为什么森林是信任边界，而不是域，因为这个高架SID（以及许多其他的）不能跨越信任边界，除非目标域是在同一个森林内。

**森林是信任边界，而不是域**，这句话其实我困惑了很久，知道今天，在翻阅了无数文档后，没有实战过的我才明白他真正的含义。

**森林内的域可以被设置为 “quarantined”，当被设置为该属性后，“Enterprise Domain Controllers”（S-1-5-9）的SID不会被过滤，且只允许该SID传递，他的组SID为516**



![image-20220224125315886](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125315886.png)





“[*The only SIDs that are allowed to be passed from such a domain are the “Enterprise Domain Controllers” (S-1-5-9) SID and those described by the trusted domain object (TDO).*](https://msdn.microsoft.com/en-us/library/cc237940.aspx)” 



[**总结：**]

**跨森林的信任在默认情况下是严格过滤的**，不允许来自该森林之外的任何SID通过该信任。然而，破坏你所信任的森林的攻击者可以冒充该森林的任何用户，从而获得明确授予该森林的用户/组的资源

如果为跨森林信任启用了SID历史记录，安全性就会被大大削弱，攻击者可以**冒充RID大于1000的任何组的组员**，在大多数情况下，这会导致森林被破坏。例如，Exchange安全组，在许多设置中允许特权升级到域管，都有大于1000的RID



## 组的关系



[Will Schroeder](https://harmj0y.medium.com/)在《[A Pentester’s Guide to Group Scoping](https://posts.specterops.io/a-pentesters-guide-to-group-scoping-c7bbbd9c7560)》一文中详细描写了AD组的关系以及PowerView查询的实现，这里也只做重点整合。

[Active Directory groups](https://technet.microsoft.com/en-us/library/dn579255(v=ws.11).aspx)一般有两种类型，*distribution groups 和security groups* 。*Distribution groups* 不能够控制对资源的访问，它用于创建电子邮件分发列表。而安全组可以控制访问， 用来分配共享资源的权限。



**在活动目录中，有两种形式的通用安全主体(security principals)：用户账户和计算机账户**



**与分发组一样，安全组也可以作为一个电子邮件实体使用。向该组发送电子邮件时，会将该信息发送给该组的所有成员。**





这里有一个列表，它来自微软的[官方文档](https://docs.microsoft.com/zh-cn/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn579255(v=ws.11)?redirectedfrom=MSDN)，并且说明了每个类型的组的作用域和成员范围

- Universal（通用组）:如果需要一个包含来自同一林中一个或多个域的成员的组，并且可以被授予对该林中任何资源的访问权限，则需要一个通用范围

  - 可以包含的成员 : 来自同一森林中任何域的账户、同一森林中任何域的全局组、来自同一森林中的任何域的其他通用组
  - 可以被作为成员包含进 : 同一森林中的其他通用组、同一森林或信任森林中的域本地组、同一森林或信任森林中的计算机上的本地组(local group)
  - 授权范围 : 在同一森林或信任森林中的任何域上
- Global （全局组）: 全局组不能跨域嵌套，这意味着来自一个域的全局组不能嵌套在另一个域的组中。此外，来自一个域的用户/计算机不能嵌套在另一个域的全局组中，这就是为什么来自一个域的用户没有资格成为外部域中“域管理员”的成员（由于其全局范围），如果想要一个可以在林或信任域中的任何域中使用的组，但只能包含来自该组域的用户，请使用全局组。

  - 可以包含的成员 : 来自同一域的账户、同一域中的其他全局组
  - 可以被作为成员包含进 : 来自同一森林中的任何域的通用组、来自同一域的其他全局组、来自同一森林中的任何域的域本地组，或来自任何信任域的域本地组
  - 授权范围 : 在同一森林中的任何域，或信任的域或森林上
- Domain Local (域本地组) : 当前域的本地组，旨在帮助管理对单个域内资源的访问，**和local gourp不一样，后者是计算机中的本地用户组**，如果想要一个组只能授予对同一域中资源的访问权限，但可以包含任何其他组范围（包括跨外部信任的用户），请使用Domain Local

  - 可以包含的成员 : 来自任何域或任何信任域的帐户、来自任何域或任何信任域的全局组、来自同一森林中任何域的通用组、来自同一域的其他域本地组、来自其他森林和外部域的账户、全局组和通用组
  - 可以被作为成员包含进 : 来自同一域的其他域本地组、同一域中的计算机上的本地组(local group)(不包括具有知名SID的内置组，例如本地Administartors组)
  - 授权范围 : 同一个域中分配权限



![image-20220224125326301](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125326301.png)


LDAP组过滤器

```powershell
#Domain Local 
(groupType:1.2.840.113556.1.4.803:=4)

#Global scope
(groupType:1.2.840.113556.1.4.803:=2)

#Universal scope
(groupType:1.2.840.113556.1.4.803:=8)

#Security Group
(groupType:1.2.840.113556.1.4.803:=2147483648)

#默认组
(groupType:1.2.840.113556.1.4.803:=1)
```





### 一些众所周知的组(默认安全组)



默认安全组是在Active Diretory域被创建时自动创建的安全组，这些组被自动分配了一组用户和权限，用来执行域内特定操作



这些默认安全组可以帮助我们更快的定位和利用域攻击



关于这些默认安全组的列表，请查看[微软官方文档](https://docs.microsoft.com/zh-cn/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn579255(v=ws.11)?redirectedfrom=MSDN#active-directory-default-security-groups-by-operating-system-version)和[ADsecurity的文章](https://adsecurity.org/?p=3700)



## 全局目录 (Global Catalog)



微软的[官方文档](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc728188(v=ws.10)?redirectedfrom=MSDN)写的很解释



全局编录是 Active Directory 林中所有对象的部分副本，这意味着其中包含一些对象属性（但不是全部）。此数据在标记为林的全局编录的所有域控制器之间复制。全局目录的一个要点是允许快速进行对象搜索和消除冲突，而无需引用其他域（[更多信息在这里](https://technet.microsoft.com/en-us/library/cc978012.aspx)）。从进攻的角度来看，好的副作用是我们可以通过对主域控制器的简单查询来快速查询有关森林中所有域和对象的信息

Powerview查找全局目录

```
Get-ForestGlobalCatalog
```



powerview搜索全局目录

```
-SearchBase
#指定 LDAP 搜索字符串时将LDAP://...替换为GC://
```



**我们只需与同一域中的域控制器通信，就可以轻松地枚举森林中任何域的任何通用组的成员**

```powershell
#powerview
Get-DomainGroup -SearchBase "GC://testlab.local" -Properties grouptype,name,member -LDAPFilter '(member=*)'
```





## 跨域转介处理



### Kerberos简单描述

如果客户机使用 Kerberos V5 进行认证，它将从其帐户域中的域控制器向目标域中的服务器请求一个票据。Kerberos密钥分发中心（KDC）作为客户机和服务器之间的可信中介；它提供一个会话密钥，使双方能够相互认证。如果目标域与当前域不同，KDC会遵循一个逻辑过程来确定是否可以引用认证请求，过程大概如下

1. 当前域是否被被请求的服务器的域直接信任？
   - 如果是，则向客户发送一个转介到被请求域的请求。
   - 如果不是，则进入下一步骤。
2. 在当前域和信任路径上的下一个域之间是否存在一个传递性的信任关系？
   - 如果是，向客户发送一个转介到信任路径上的下一个域的信息。
   - 如果没有，向客户端发送一个拒绝登录的消息。

### NTLM 协议简单描述

如果客户端使用NTLM进行认证，最初的认证请求会直接从客户端到目标域的资源服务器。该服务器创建一个挑战，客户端对此作出回应。然后，该服务器将用户的响应发送到其计算机账户域中的域控制器。这个域控制器根据其安全账户数据库检查用户账户。如果该账户不存在于数据库中，域控制器通过使用以下逻辑来决定是否执行直通式验证，转发请求，或拒绝请求。

1. 当前的域是否与用户的域有直接的信任关系？

   - 如果是，域控制器将客户机的凭证发送给用户域中的域控制器进行穿透式验证。
   - 如果没有，请进入下一步。

2. 当前的域是否与用户的域有一个相互信任的关系？

   - 如果是，就把认证请求传递给信任路径中的下一个域。这个域控制器重复这个过程，根据它自己的安全账户数据库检查用户的凭证。

   - 如果不是，则向客户发送一个拒绝登录的消息。

### 其他认证协议

Windows 2000 Server和Windows Server 2003也支持跨林信任的Digest和Schannel认证。这使Web服务器等技术能够在多域环境中完成其任务。安全套接字层（SSL）协议和对活动目录用户账户的证书映射使用Schannel，而互联网信息服务（IIS）使用Digest。在信任森林或域之间的防火墙只允许HTTP流量通过的情况下，信任域之间可能需要Digest和Schannel认证。Digest可以在HTTP头文件中进行。

Windows 2000 Server和Windows Server 2003的认证协商决定了通过信任使用的认证协议，只要通用的传递机制能够在目标域中找到适当的域控制器。管理员也可以选择实施另一个认证协议的安全支持提供者（SSP）。如果该SSP与Windows 2000 Server和Windows Server 2003分布式系统兼容，它将以标准的Windows 2000 Server和Windows Server 2003 SSP跨域工作的方式，在跨域信任上工作。



## 基于Kerberos的认证请求在域信任上的处理



同一森林中的AD域是由双向的、相互信任的隐含连接的，因此从一个域到另一个域的认证请求被路由以提供对跨域资源的无缝访问。



![image-20220224125339096](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125339096.png)



<center>通过域信任的Kerberos认证流程图</center>



1. User1 使用来自europe.tailspintoys.com域的凭证登录到Workstation1,认证的域控制器向User1发出一个票据授予票（TGT）
2. 用户试图访问位于asia.tailspintoys.com域的文件服务器上的共享资源（\fileserver1\share）, Workstation1 联系自身域中的域控制器 (ChildDC1) 上的 Kerberos 密钥分发中心 (KDC)，并附上获得的TGT去请求 FileServer1 服务主体名称 (SPN) 的service ticket 
3. ChildDC1 在其域数据库中没有找到该 SPN，于是查询全局目录(global catalog)以了解森林中是否有域包含该 SPN。全局目录将请求的信息发回给 ChildDC1
4. ChildDC1向Workstation1发送转介信息
5. Workstation1联系ForestRootDC1（其父域）中的域控制器，要求转介到Child2域的域控制器（ChildDC2）。ForestRootDC1向工作站1发送转介
6. Workstation1联系ChildDC2上的KDC，并为用户协商一个票据，以获得对FileServer1的访问
7. 一旦Workstation1有了service ticket ，它就把票据发送给FileServer1，后者读取用户的安全凭证并相应地构建一个访问令牌

## 基于Kerberos的认证请求在森林信托中的处理



在首次建立森林信任时，**每个森林都会收集其伙伴森林中的所有受信任的名称空间**，并将这些信息存储在一个TDO中。受信任的名称空间包括域树名称、用户主体名称（UPN）后缀、服务主体名称（SPN）后缀，以及其他森林中使用的安全标识（SID）名称空间。**TDO对象被复制到全局目录中**。

在认证协议能够遵循森林信任路径之前，资源计算机的服务主体名称(SPN)必须被解析到其他森林中的某个位置。

当一个森林中的workstation试图访问另一个森林中的资源计算机上的数据时，Kerberos会联系域控制器，以获得资源计算机的SPN的service ticket。一旦域控制器查询全局目录并确定该SPN与域控制器不在同一林，域控制器就会向工作站发送其父域的推荐信。在这一点上，workstation查询父域的service ticket据，并继续跟踪转介链，直到它到达资源所在的域。



![image-20220224125347863](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125347863.png)

<center>通过林信任的Kerberos认证过程</center>

1. User1使用来自europe.tailspintoys.com域的凭证登录到Workstation1,获得了自身域的TGT，然后，该用户试图访问位于 usa.wingtiptoys.com 森林中的 FileServer1 的共享资源(cifs)
2. Workstation1 联系其域中的域控制器（ChildDC1）上的 Kerberos 密钥分发中心（KDC），并请求 FileServer1 SPN 的Service Ticket
3. ChildDC1 在其域数据库中没有找到该 SPN，于是查询全局目录，看 tailspintoys.com 林中是否有域包含该 SPN。因为全局目录只限于它自己的森林，所以没有发现这个 SPN。然后，全局目录检查它的数据库，了解与它的森林建立的任何森林信任的信息，如果发现，它将森林信任中列出的名称后缀（TDO）与目标SPN的后缀进行比较，以找到一个匹配。一旦找到匹配，全局目录会向ChildDC1提供一个路由提示。路由提示有助于将认证请求引向目标林，并且只在所有传统的认证渠道（本地域控制器，然后是全局目录）都无法定位SPN时使用。
4. ChildDC1向Workstation1发送其父域的推荐信息
5. Workstation1联系ForestRootDC1（其父域）中的域控制器，以获得对wingtiptoys.com森林的森林根域中的域控制器（ForestRootDC2）的推荐票([使用信任密钥加密的TGT](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-kile/bac4dc69-352d-416c-a9f4-730b81ababb3))，ForestRootDC复制了其TGT中的PAC，并且将使用信任密钥加密的推荐票(TGT)和签名的[PAC副本](https://dirkjanm.io/active-directory-forest-trusts-part-one-how-does-sid-filtering-work/#from-a-to-b-whats-in-a-pac)发送给了Workstation1
6. Workstation1联系wingtiptoys.com林中的ForestRootDC2，发送推荐票(TGT)给ForestRootDC2，以获得所请求服务的service ticket
7. ForestRootDC2联系它的全局目录来寻找SPN，全局目录找到一个匹配的SPN并把它送回给ForestRootDC2
8. ForestRootDC2然后将转介到usa.wingtiptoys.com的信息发回给Workstation1
9. Workstation1联系ChildDC2上的KDC，并为User1协商票据(ST)以获得对FileServer1的访问，KDC创建跨域 ST 时，如有必要，将复制和过滤来自 TGT 的 PAC。**通常，不属于受信任域的林的额外 SID 会被删除(SID Filter)**
10. 一旦Workstation1有了service ticket，它就会将service ticket发送给FileServer1，后者会读取用户1的安全凭证并相应地构建一个访问令牌



**通常情况下，跨领域 TGT 使用 RC4 算法而不是 AES256 进行加密，他将更容易被破解**



**从本质上讲，信任所做的就是把两个域的认证系统连接起来，并允许认证流量通过一个转介系统在它们之间流动。如果用户请求访问他们当前所在域之外的资源的服务主体名称（SPN），他们的域控制器将返回一个特殊的推荐票，该推荐票指向外域的密钥分发中心（KDC，在Windows情况下是域控制器）**



**如果还是不能够理解微软文档所发布的内容，可以参考zer1t0的[Attacking Active Directory: 0 to 0.9](https://zer1t0.gitlab.io/posts/attacking_ad/#kerberos-across-domains)**，他在文中这样写道:

```
KDC foo.com                                                    KDC bar.com
    .---.                                                          .---.
   /   /|                       .---4) TGS-REQ (TGT bar)------->  /   /|
  .---. |                       |    + SPN: HTTP\srvbar          .---. |
  |   | '                       |    + TGT client > bar.com      |   | '
  |   |/                        |                                |   |/ 
  '---'                         |   .--5) TGS-REP--------------< '---'
  v  ^                          |   | + ST client > HTTP/srvbar
  |  |                          |   |
  |  |                          ^   v                                   .---.
  |  '-2) TGS-REQ (TGT foo)--<  _____                                  /   /|
  |   + SPN: HTTP\srvbar       |     | <----------1) SPNEGO---------> .---. |
  |   + TGT client > foo.com   |_____|                                |   | '
  |                            /:::::/ >----6) AP-REQ---------------> |   |/
  '--3) TGS-REP--------------> client     + ST client > HTTP/srvbar   '---'  
    + TGT client > bar.com    (foo.com)                               srvbar
                                                                    (bar.com)
```

1. 来自 foo.com 域的客户端/用户使用 SPNEGO 与来自 bar.domain 的所需服务协商 Kerberos 身份验证，在本例中为 HTTP\srvbar（服务器 srvbar 中的 Web 服务器）。
2. 客户端通过发送 TGS-REQ 消息，使用其 foo.com 的 TGT 向其 KDC 请求 HTTP\srvbar 的 ST。
3. KDC 确定此服务位于信任域 bar.com 中。因此 foo.com KDC 通过使用跨领域信任密钥（信任双方共享的密钥）作为加密（和 PAC 签名）密钥为 bar.com 创建一个 TGT。然后，KDC 在 TGS-REP 消息中返回 bar.com TGT。 bar.com TGT 中包含的 PAC 是 foo.com TGT PAC 的副本。
4. 客户端使用 bar.com TGT 通过发送 TGS-REQ 消息向 bar.com KDC 请求 HTTP\srvbar ST。
5. bar.com KDC 通过使用跨领域信任密钥解密票证来检查票证。然后它为客户端的 HTTP\srvbar 创建一个 ST。创建新 ST 时，如有必要，将复制和过滤来自 TGT 的 PAC。通常，不属于受信任域的林的额外 SID 会被删除。
6. 最后，客户端使用 ST 对 HTTP\srvbar 服务进行身份验证。



## 利用思路与策略

在[harmj0y](http://www.harmj0y.net/blog/redteaming/a-guide-to-attacking-domain-trusts/)的文章中，详细描述了传统的利用思路和一些基础知识，大致上内容如下:



1. 枚举并列出当前域的所有信任关系，找出攻击路径和边界。可以使用[trust_explorer.py](https://github.com/sixdub/DomainTrustExplorer/blob/master/trust_explorer.py)、[BloodHound](https://github.com/BloodHoundAD/BloodHound/)等可视化工具进行分析
2. 枚举一个域中的任何用户、组、计算机、服务等， 发现可以访问另一个域中的资源（即本地管理员组的成员资格)、其他域的用户等，**找到一个可以跨越映射信任边界的桥梁**
   1. 找到可以访问另一个域中的资源（即目标域的本地域管理员组的成员资格，或 DACL ACE 条目）
   2. 在当前域的组中寻找包含的目标域的成员。

3. 进行跨域 / 林 横向移动
   1. 如果下一个域跃点与我们从/通过的域在同一个林中，并且我们能够破坏子域的 krbtgt 哈希，那么直接进入**Trustpocalypse – SID 增加森林内信托**
   2. 如果我们无法破坏当前/枢轴子域中的提升访问权限，或者如果信任攻击路径中的下一步是外部/林信任，那么进入**寻找利用条件**章节

### 寻找利用条件

在这章节中将寻找林 / 域边界进行横向移动

来自一个域的安全主体（用户/组）可以通过三种主要方式访问另一个外部/信任域中的资源：

- 它们可以添加到单个机器上的本地组，即服务器上的本地“管理员”组
- 它们根据信任类型和组范围可以添加到外部域中的组中。
- 它们可以作为主体添加到访问控制列表中，对我们来说最有趣的是作为 DACL 中的 ACE 中的主体





#### 本地组成员资格



通过 SAM-Remote (SAMR) 协议针对受害者的域计算机远程查询 Windows 安全帐户管理器 (SAM)，允许攻击者获取所有域和本地用户及其组成员身份，并在受害者网络中映射可能的路由，. [BloodHound](https://github.com/adaptivethreat/BloodHound)已经支持了[这一操作](https://www.blackhat.com/docs/eu-16/materials/eu-16-Beery-Grady-Cyber-Judo-Offensive-Cyber-Defense.pdf)

通过远程 SAM (SAMR) 或通过 GPO 关联来枚举一个或多个系统的本地成员资格。手动执行此操作的 PowerView 函数是 `Get-NetLocalGroupMember <server>`。在这里有[相关案例和详细分析](https://harmj4.rssing.com/chan-30881824/article49.html)





####  Foreign Group 外部安全组的成员资格



 Active Directory 组的成员属性和用户/组对象的 memberOf 属性具有称为[链接属性](https://docs.microsoft.com/zh-cn/windows/win32/ad/linked-attributes?redirectedfrom=MSDN)的特殊类型的关系。详细可以查看[这篇文章](https://posts.specterops.io/hunting-with-active-directory-replication-metadata-1dab2f681b19)

以下是三个组范围的细分，其中展示了可以包含哪些类型的外部成员：

- 域本地组可以将林内跨域用户（与组在同一林中的用户）添加为成员，也可以将林间跨域用户（外部安全主体）添加为成员。
- 全局组不能具有任何跨域成员资格，即使在同一个林中也是如此。在这里可以忽略
- 通用组可以将林中的任何用户作为成员，但“外部安全主体”（即来自 林 / 外部信任的用户）不能成为通用组的一部分。

**当在森林中的域和该森林之外的域之间建立信任时，来自外部域的安全主体可以访问内部域中的资源。 Active Directory 在内部域中创建一个外部安全主体对象，以表示来自受信任的外部域的每个安全主体。这些外部安全主体可以成为内部域中域本地组的成员**

所以找到这些组和组中的成员，便是找到了穿越边界的桥梁

**来自林/外部信任的用户会被标识`CN=foreign security principals`**,这些通过林/外部信任嵌套在域中的组中的用户，可以使用`CN=ForeignSecurityPrincipals,DC=domain,DC=com`作为过滤器查询



![image-20220224125359984](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125359984.png)







#### 外部ACL实体



Active Directory 对象的大多数 ntSecurityDescriptor 属性可供任何经过域身份验证的用户访问，并且会在全局编录中复制。

这意味着，当攻击者在当前域环境的上下文中时，将可以查询信任域中所有对象的DACL，并枚举过滤出外部安全主体的所有ACE条目

```powershell
Get-DomainObjectACL -Domain <domain.fqdn>
```





### 信息收集中一些输出的内容解释



**TrustType(信任的类型)**

- **DOWNLEVEL** (0x00000001)  ：一个未运行 Active Directory 的受信任的 Windows 域。对于那些不熟悉该术语的人，这在 PowerView 中以 WINDOWS_NON_ACTIVE_DIRECTORY 的形式输出
- **UPLEVEL** (0x00000002)  ：一个运行 Active Directory 的受信任的 Windows 域。对于不熟悉该术语的人来说，这在 PowerView 中输出为 WINDOWS_ACTIVE_DIRECTORY。
- **MIT** (0x00000003) ：运行非 Windows (*nix)、符合 RFC4120 的 Kerberos 分发的受信任域



**[TrustAttributes](https://msdn.microsoft.com/en-us/library/cc223779.aspx)(信任属性)**

- **NON_TRANSITIVE** (0x00000001) : 不能传递信任。也就是说，如果 DomainA 信任 DomainB 而 DomainB 信任 DomainC，那么 DomainA 不会自动信任 DomainC。此外，如果信任是不可传递的，那么您将无法从非传递点的链上的信任中查询任何 Active Directory 信息。外部信任是隐含的不可传递的。
- **UPLEVEL_ONLY** (0x00000002) :  只有 Windows 2000以上操作系统和的客户端可以使用信任。
- **QUARANTINED_DOMAIN** (0x00000004)  :  SID 过滤已启用。为简单起见，使用 PowerView 输出为 FILTER_SIDS。
- **FOREST_TRANSITIVE** (0x00000008) : 至少运行域功能级别 2003 或更高级别的两个域林的根之间的跨林信任。
- **CROSS_ORGANIZATION** (0x00000010) : 信任不属于组织的域或林，它添加了 OTHER_ORGANIZATION SID。根据[这篇文章](https://imav8n.wordpress.com/2008/07/30/trust-attribute-cross_organization-and-selective-auth/)的说法，这意味着启用了选择性身份验证安全保护。有关更多信息，请查看此 [MSDN 文档](https://technet.microsoft.com/en-us/library/cc755321(v=ws.10).aspx#w2k3tr_trust_security_zyzk)。
- **WITHIN_FOREST** (0x00000020) : 受信任域在同一个林中，表示父->子或交叉链接(快捷方式信任)关系
- **TREAT_AS_EXTERNAL** (0x00000040) : 出于信任边界的目的，信任将被视为外部信任。根据文档，“如果设置了此位，则出于 SID 过滤的目的，对域的跨林信任将被视为外部信任。跨林信任的过滤比外部信任更严格。此属性将那些跨林信任放松为等同于外部信任。
- **USES_RC4_ENCRYPTION** (0x00000080)  :  如果 TrustType 是 MIT，则指定支持 RC4 密钥的信任。
- **USES_AES_KEYS** (0x00000100) : 它指定 AES 密钥用于加密 KRB TGT。
- **CROSS_ORGANIZATION_NO_TGT_DELEGATION** (0x00000200) : 如果此位被设置，在此信任下授予的票据必须不被信任用于委托
- **PIM_TRUST** (0x00000400) : ["如果该位和TATE（treat as external）位被设置，那么为了SID过滤的目的，对域的跨森林信任将被视为特权身份管理信任](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/e9a2d23c-c31e-4a6f-88a0-6646fdb51a3c?redirectedfrom=MSDN)”





## 操作指导

这些工具的原理在harmj0y的《[A Guide To Attacking Domain Trusts](http://www.harmj0y.net/blog/redteaming/a-guide-to-attacking-domain-trusts/)》一文中有详细的解释

信息收集可以用来判断 域/林 之间的信任关系，快速找到目标跃点和边界，从而更快，更准的定位和拿下目标



### 在无法提权且位于林的子域中时

如果您当前位于林中的子域中，并且在所述子域中没有提升的访问权限，则可以运行 PowerView 的 Get-DomainForeignUser 函数来枚举用户当前域之外的组中的用户。这是域的“传出”访问，即可能对同一林中的其他域组具有某种访问权限的用户/组。此功能还可用于映射其他林内域用户/组关系：



![image-20220224125408661](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125408661.png)





### 如果目标位于外部域 / 域森林 或者同一林中的目标域



如果您的目标是外部/林域或同一林中的目标域，则可以使用 PowerView 的 Get-DomainForeignGroupMember -Domain <target.domain.fqdn> 函数。这将枚举目标域中包含不在目标域中的用户/组的组。这是域的“传入”访问，即目标域中具有入站成员关系的组： 



![image-20220224125420604](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125420604.png)





### 快速枚举作为当前/目标林中域内组成员的所有外部安全主体



可以使用 LDAP 过滤器查询任何全局目录 **(objectclass=foreignSecurityPrincipal)**而且由于这些外部主体只能添加到具有域本地范围的组中，我们可以从专有名称中提取外部用户添加到的域，直接查询该域以查找具有成员的域本地范围组，假设我们有某种类型与该目标域的直接或传递信任。这使我们可以将这些域本地组的成员身份与外国用户列表进行比较：

```powershell
$ForeignUsers = Get-DomainObject –Properties objectsid,distinguishedname –SearchBase "GC://sub.dev.testlab.local" –LDAPFilter '(objectclass=foreignSecurityPrincipal)' | ? {$_.objectsid -match '^S-1-5-.*-[1-9]\d{2,}$'} | Select-Object –ExpandProperty distinguishedname
$Domains = @{}
 
$ForeignMemberships = ForEach($ForeignUser in $ForeignUsers) {
    #  提取外来用户加入的域
    $ForeignUserDomain = $ForeignUser.SubString($ForeignUser.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
    #检查我们是否已经枚举了这个域
    if (-not $Domains[$ForeignUserDomain]) {
        $Domains[$ForeignUserDomain] = $True
        # 枚举给定域中具有任何成员集的所有域本地组
        Get-DomainGroup –Domain $ForeignUserDomain –Scope DomainLocal –LDAPFilter '(member=*)' –Properties distinguishedname,member | ForEach-Object {
            # 检查域本地组和外部用户之间是否有任何重叠
            if ($($_.member | Where-Object {$ForeignUsers  -contains $_})) {
                $_
            }
        }
    }
}
 
$ForeignMemberships | fl
```



![image-20220224125427988](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125427988.png)





### Trustpocalypse – SID 增加森林内信托 AKA. SID History 攻击

相信很多人都知道SID History攻击，在mimikatz实现这个攻击之前，更多的人们都是去修改AD数据库等繁琐操作，mimikatz的作者 [Benjamin Delpy](https://twitter.com/gentilkiwi) 拯救了个世界，下面是一些该攻击的原理和利用方式







mimikatz通过设置票据 [KERB_VALIDATION_INFO](https://msdn.microsoft.com/en-us/library/cc237948.aspx) 结构的`extraDs`部分（该结构定义了[DC提供的用户的登录和授权信息](https://msdn.microsoft.com/en-us/library/cc237948.aspx)）来实现这一点。 `extraSids`部分被描述为“[指向Kerb_sid_and_Attributes结构列表的指针，该结构包含与域中的域中的域中的组的SID列表](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-pac/69e86ccc-85e3-41b9-b514-7d969cd0ed73?redirectedfrom=MSDN)”（这里定义了Kerb_sid_and_Attributes结构）

他在数据包中看起来像这样

```
Username: Superuser
Domain SID: S-1-5-21-3286968501-24975625-1618430583
UserId: 500
PrimaryGroupId 513
Member of groups:
  ->   513 (attributes: 7)
  ->   512 (attributes: 7)
  ->   520 (attributes: 7)
  ->   518 (attributes: 7)
  ->   519 (attributes: 7)
LogonServer:  
LogonDomainName:  FOREST-A

Extra SIDS:
  ->   S-1-5-21-3286968501-24975625-1618430583-1604
  ->   S-1-18-1
Extra domain groups found! Domain SID:
S-1-5-21-2897307217-3322366030-3810619207
Relative groups:
  ->   1107 (attributes: 536870919)
```



[这篇文章](https://adsecurity.org/?p=1588)与[许多文章](https://zer1t0.gitlab.io/posts/attacking_ad/#sid-history-attack)都讲述了SID History攻击的实现和SID History的作用，这里不再赘述



**之前我对域信任和域架构有一定的误解，SID在子域攻击同林根域时并不会被SID Filter过滤，但是攻击其他林（林信任/外部信任）的目标时，将会启用上述的SID Filter**。使用了被过滤的SID则会攻击失败，但是我们可以使用**RID高于1000的目标**进行SID攻击



SID History注入命令

```powershell
PS C:\> .\mimikatz.exe

  .#####.   mimikatz 2.2.0 (x64) #19041 Sep 18 2020 19:18:29
 .## ^ ##.  "A La Vie, A L'Amour" - (oe.eo)
 ## / \ ##  /*** Benjamin DELPY `gentilkiwi` ( benjamin@gentilkiwi.com )
 ## \ / ##       > https://blog.gentilkiwi.com/mimikatz
 '## v ##'       Vincent LE TOUX             ( vincent.letoux@gmail.com )
  '#####'        > https://pingcastle.com / https://mysmartlogon.com ***/

mimikatz # sekurlsa::krbtgt

Current krbtgt: 5 credentials
         * rc4_hmac_nt       : 1bf960a6af7703f75b1a2b04787c85fb
         * rc4_hmac_old      : 1bf960a6af7703f75b1a2b04787c85fb
         * rc4_md4           : 1bf960a6af7703f75b1a2b04787c85fb
         * aes256_hmac       : 8603210037f738c50120dbe0f2259466fd4fdd1d58ec0cf9ace34eb990c705a3
         * aes128_hmac       : 204be93d3c18326bf0e6675eb0a32202

mimikatz # kerberos::golden /admin:Administrator /domain:it.poke.mon /sid:S-1-5-21-1913835218-2813970975-3434927454 /sids:S-1-5-21-4285720809-372211516-2297741651-519 /aes256:8603210037f738c50120dbe0f2259466fd4fdd1d58ec0cf9ace34eb990c705a3 /ptt /groups:512,520,572
User      : Administrator
Domain    : it.poke.mon (IT)
SID       : S-1-5-21-1913835218-2813970975-3434927454
User Id   : 500
Groups Id : *512 520 572
Extra SIDs: S-1-5-21-4285720809-372211516-2297741651-519 ;
ServiceKey: 8603210037f738c50120dbe0f2259466fd4fdd1d58ec0cf9ace34eb990c705a3 - aes256_hmac
Lifetime  : 5/13/2021 9:36:28 AM ; 5/11/2031 9:36:28 AM ; 5/11/2031 9:36:28 AM
-> Ticket : ** Pass The Ticket **

 * PAC generated
 * PAC signed
 * EncTicketPart generated
 * EncTicketPart encrypted
 * KrbCred generated

Golden ticket for 'Administrator @ it.poke.mon' successfully submitted for current session
```



### 域间TGT 伪造

在上文中讲到，使用Kerberos进行跨域操作会引入一种新的TGT，即**跨域TGT**。这种 TGT 与普通的 TGT 完全一样，只是它用域间信任密钥(信任账户的 NT hash)进行了加密，这是一个允许信任双方在它们之间进行通信的秘密密钥。秘密密钥被存储为代表该信托的用户账户的密钥。



为了获得域间信任密钥，通常需要[转储域数据库](https://zer1t0.gitlab.io/posts/attacking_ad/#domain-database-dumping)。此外，有一种情况是，可以[通过Kerberoast获得信任密钥](https://blog.xpnsec.com/inter-realm-key-roasting/)。



当一个信任被创建时，**信任密码可以由一个人选择，所以有可能设置了一个弱密码**。然后，当得到一个用信任钥匙加密的域间TGT，就可以试图破解它以得到信任密码（它被用来生成所有的Kerberos信任钥匙）。但是请记住，信任密码和机器密码一样，通常每30天更换一次(自动)。

一旦你得到信任密钥，要[创建一个跨域票据](https://adsecurity.org/?p=1588)，你可以使用[mimikatz kerberos::golden](https://github.com/gentilkiwi/mimikatz/wiki/module-~-kerberos#golden--silver)命令或[impacket ticketer.py](https://github.com/SecureAuthCorp/impacket/blob/master/examples/ticketer.py)脚本。然后你可以把它当作任何票据来使用。**信任间票据是用RC4密钥加密的**，也就是信任账户的NT哈希值。



### 一些零零散散的内容



#### 获取域信任

```powershell
#powerview

#.NET方法查询
Get-DomainTrust -NET

#Win32API查询
Get-DomainTrust -API
nltest /trusted_domains

#LDAP
dsquery * -filter "(objectClass=trustedDomain)" -attr *

 .\adfind.exe -f objectclass=trusteddomain
 
 Get-DomainTrust
 
 #从全局目录中查询(会有更多结果)
Get-DomainTrust -SearchBase “GC://$($ENV:USERDNSDOMAIN)”
```



#### 获取林信任

```powershell
#powerview

#.NET方法查询
Get-ForestTrust

```



#### 数据可视化



[BloodHound](https://github.com/BloodHoundAD/BloodHound/)，一个大家都喜欢的工具，他生成的可视化界面看起来像这样

![image-20220224125447225](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125447225.png)







#### 思维导图



我绘制了攻击思路的一张思维导图，由于是初次学习和制作，可能存在一些问题，但是日后会慢慢改进

**当你遇到无法理解的问题后，可以尝试google搜索和自己搭建靶机模拟实战**



![image-20220224125459369](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125459369.png)







## 举个栗子



网络拓扑图如下所示，箭头方向部是信任方向，而是和信任方向相反的访问方向



![image-20220224125509949](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125509949.png)



### 根据战术思路



假设我们在 external.local 中登陆了一个帐户，由于 sub.dev.testlab.local 信任 external.local，则external.local 可以从 sub.dev.testlab.local 查询信息。而 sub.dev.testlab.local不能对 external.local 做同样的事情(单向信任)。我们可以查询sub.dev.testlab.local 拥有的信任：

![image-20220224125524468](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125524468.png)



但这只会返回 sub.dev.testlab 与其他域（dev.testlab.local 和 external.local）的直接信任。如果我们能通过 sub.dev.testlab 去查询GC全局目录（并非总是可能）就能返回整个森林中的所有域信任:



![image-20220224125533194](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125533194.png)







但是，由于这是 external.local 与 sub.dev.testlab.local 的单向、非传递外部信任，因此我们无法在 external.local 上通过 sub.dev.testlab.local 对contoso.local 具有的信任进行查询，kerberos会返回一个错误，他看起来像这样:

![image-20220224125538880](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125538880.png)



所以，我们可以用下面的命令查询sub.dev.testlab.local 中包含外部成员的组，并找到拥有  external.local 成员的组和用户

还记得框出的标识的意思吗？**在真实环境中，可能存在几十上百个这样的组，快速寻找的方式是在管道符后面增加域SID筛选条件**，类似这样 ` Get-DomainForeignGroupMember -Domain sub.dev.testlab.local  | findstr "S-1-5-21-....."`



![image-20220224125545201](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125545201.png)



接下来，针对性的对这些筛选出的账号进行攻击和控制，以将信任转移到 sub.dev.testlab.local(跃点)，Get-DomainForeignUser在上图无法使用，因为external.local 是单向的外部信任，由于 external.local -> sub.dev.testlab.local 是一个外部信任关系，它是隐式不可传递的，因此无法查询 dev.testlab.local 或 testlab.local 的域本地组(Domain Local)成员资格。

如果我们随后能够破坏 sub.dev.testlab.local 中的域管理员（或等效，只要你能够DCsync攻击）凭据，那么可以构造一个[sidHistory-trust-hopping Golden Ticket](https://adsecurity.org/?p=1640)(SID History或信任密钥伪造的金票)。如果我们无法获得提升的访问权限，运行 Get-DomainForeignUser 以查看来自 sub.dev.testlab.local 的任何用户是否在外部域/其他子域/父域的组中。



**还记得吗，通用组能够包含**：

**来自同一森林中任何域的账户**、同一森林中任何域的全局组、来自同一森林中的任何域的其他通用组





**而本地域组(Domain Local) 可以包含:**

**来自任何域或任何信任域的帐户**、来自任何域或任何信任域的全局组、来自同一森林中任何域的通用组、来自同一域的其他域本地组、来自其他森林和外部域的账户、全局组和通用组





**而全局组不能包含任何跨域的成员或组**

这里只搜索到了包含 sub.dev.testlab.local 用户的dev.testlab.local的通用组



![image-20220224125601145](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125601145.png)



我们还将运行 Get-DomainForeignGroupMember -Domain dev.testlab.local 和 Get-DomainForeignGroupMember -Domain testlab.local 以查看对 dev.testlab.local 和 testlab.local 域组中拥有传入访问权限的sub.dev.testlab.local的用户和组：



![image-20220224125606903](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125606903.png)



![image-20220224125619129](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125619129.png)



如果我们能够通过上述任一方法破坏部分或全部 testlab.local(森林根目录)，我们将运行 Get-DomainForeignGroupMember -Domain contoso.local 和 Get-DomainForeignGroupMember -Domain prod.contoso.local 以查看在CONTOSO 林中具有外部组成员身份的 TESTLAB林的用户



![image-20220224125625563](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125625563.png)



在此过程中，我们可以针对目标选择的服务器（包括 DC）运行 Get-NetLocalGroupMember <foreign,server>，以查看是否有任何用户通过机器本地组跨越边界。我们还可以使用具有各种过滤器的目标 Get-DomainObjectACL -Domain <foreign.domain> 来检查外部 ACL 成员资格。



### 伪造跨信任金票



我们可以伪造跨领域信任票来利用信任关系。正如 Sean 在他的“It's [All About Trust](https://adsecurity.org/?p=1588)”帖子中很好地介绍了这一点。

回想一下 Kerberos 如何跨信任工作的解释：



![image-20220224125633880](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125633880.png)



因此，当用户将这个**跨域TGT推荐** 提交给外部域时，且该跨TGT由跨域**信任密钥**签名。由于**外部域**信任发布该推荐票的域。因此**外部域**信任用户的 TGT 及其包含的所有信息是准确的。

所以，跨域TGT是由**信任密钥**签名和加密的，我们只要窃取该跨域信任密钥的NT hash，我们就能伪造出一份跨域TGT，并且在TGT中伪造任何身份

我们可以通过DCsync和数据库转储 信任账户来窃取NT hash



![image-20220224125639381](../assets/2022-02-17-Active-Directory-%E5%9F%9F%E6%A3%AE%E6%9E%97%E5%8F%8A%E4%BF%A1%E4%BB%BB%E9%97%AE%E9%A2%98%E7%9A%84%E5%AD%A6%E4%B9%A0/image-20220224125639381.png)



如果我们能够DCSync或者数据库转储信任账户的NT hash，那么我们就同样可以窃取krbtgt账户的NT hash，如果我们同时拥有了这两个账户的NT hash，我们就可以为**引用域**(当前域)的用户构建一个TGT和跨域TGT，伪装成能够访问外部域的任何用户/权限。

**早在 2015 年，在大家开始充分认识到金票的含义后，微软发布了允许组织更改 krbtgt 帐户密码的脚本。为了使这对单域林有效，密码必须更改两次（如果修改的密码没有成功同步，那么将会使用旧密码进行验证）。现在，由于 sidHistory-hopping 攻击的实施，森林中每个域中 krbtgt 帐户的密码必须修改两次，才可以解除攻击。**

[**注意**:] 虽然根据 Active Directory 技术规范的[第 6.1.6.9.6.1 节](https://msdn.microsoft.com/en-us/library/cc223791.aspx)，跨领域信任密钥每 30 天自动轮换一次，**但当 krbtgt 帐户更改时，它们不会轮换修改**。因此，如果攻击者拥有跨域密钥，他们仍然可以使用 sidHistory 方法来获得信任，我们还有很[多种方式创建AD后门](https://specterops.io/assets/resources/an_ace_up_the_sleeve.pdf)



### 跨域信任的 Kerberoasting

在之前进行AD学习时，我们讲述过[Kerberoasting](https://blog.harmj0y.net/powershell/kerberoasting-without-mimikatz/)，在现在，我们依旧可以使用[跨域信任的Kerberoasting](https://blog.xpnsec.com/inter-realm-key-roasting/)来离线爆破外部域的密码





## 参考文献



[Active Directory forest trusts part 1 - How does SID filtering work?](https://dirkjanm.io/active-directory-forest-trusts-part-one-how-does-sid-filtering-work/#golden-tickets-and-sid-filtering)



[Attacking Active Directory: 0 to 0.9](https://zer1t0.gitlab.io/posts/attacking_ad/#forests)



[A Guide to Attacking Domain Trusts](http://www.harmj0y.net/blog/redteaming/a-guide-to-attacking-domain-trusts/)



[Active Directory forest trusts part 2 - Trust transitivity and finding a trust bypass](https://dirkjanm.io/active-directory-forest-trusts-part-two-trust-transitivity/)



[It’s All About Trust – Forging Kerberos Trust Tickets to Spoof Access across Active Directory Trusts](https://adsecurity.org/?p=1588)



[How Domain and Forest Trusts Work](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc773178(v=ws.10)?redirectedfrom=MSDN)



