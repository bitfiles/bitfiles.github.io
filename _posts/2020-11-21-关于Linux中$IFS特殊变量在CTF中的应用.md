IFS是一个特殊的shell变量

```
再未定义变量名时，默认值为<space> <tab> <newline>
```

注:实验情况下只有$@，也就是$1,$2,$3...$n在未定义时可以替换为空格等
如图：
![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-439479f99e4a47e792680913ad071bd3.png)

使用$1与$a的区别，初步估计可能是因为IFS如使用字母开头，会将后方字母识别为变量名的一部分

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-fe270db6222340a881a482856e770bf4.png)

```
设定IFS值的情况下，可以将匹配到的字符替换为<space> <tab> <newline>进行分割
```

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-b46946285148455fbac3a83754b25d09.png)

也可以通过变量赋值，进行字符替换，例如:

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-3c71683bfaa045ecb0d39c9e9da8f41f.png)

## 在CTF中的应用

#### 例:[GXYCTF2019]Ping Ping Ping 1

打开链接发现让传参ip，根据参数和题目名可以推断是进行ping命令，存在命令执行漏洞

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-8c728734ed8341c5b0fbdabf4e3bda17.png)

尝试传递参数，发现可正常执行

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-eeb23dedcd41420b864e4eee4bb04ecd.png)

构造payload，尝试寻找有关flag的文件，发现提示符号被过滤

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-9214ba5939834196963b9cd474e22ca0-163764872547721.png)

尝试其他命令

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-6684dffa36f048c0bcbf23d85a1a0e3d.png)

发现正常执行，尝试查看当前目录下文件，发现flag.php

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-1fec2151582c43eb8dfceebe1ec66902.png)

打开flag.php发现是个空页面，说明可能flag被注释

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-fbfbd0f7508942aeaf9dad519cef6d51.png)

尝试使用cat命令查看flag.php，发现空格被过滤

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-51c3528a7caa414b8bf6c70031062507.png)

尝试使用IFS变量替换空格，发现flag被过滤，但是空格提示被绕过

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-c2b97f28317c4e08bc65c88d9a107319.png)

尝试查看index.php查找过滤规则，发现过滤了除$和`以外的大多数符号

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-cacfaea2357341b9a6e1caa68a4e9cc1.png)

此时有多种解决方式，先说简单的

## 方法一

使用内联注入，学过DNSLOG注入的应该都清楚，``括起来的内容会被shell直接执行，那么构造payload,发现爆出flag，至于为什么在源码里最后再说

```
cat$IFS$1`ls`
```

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-ca585703aec248df858f70593445015f.png)

## 方法二

将payload编码后使用sh命令执行

```
echo$IFS$1Y2F0IGZsYWcucGhw|base64$IFS$1-d|sh
```

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-83b2719953e1482292b533a92c00aa7b.png)

## 方法三

变量赋值后绕过

通过index.php的代码我们可以得知，当flag（因为是使用正则匹配，所以不管中间和前后有多少字符，只要在顺序中存在f->l->a->g这样的顺序就会被过滤）

那么我们需要赋值的变量不能够是上面的顺序，所以可构造以下几种payload(其他都可自己尝试)

```
a=lag;cat$IFS$1f$a.php
a=lag;b=f;cat$IFS$1$b$a.php
```

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-e39d31da8ff5439ea92c2fd529d9685f.png)

## 问题

为什么php代码显示在源码中，而不是直接输出在页面内

答：
因为在index.php的代码中可得知

![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-41d2c53c1246470f97c658643083448a.png)

在输出$a后再未调用$a和执行其他代码，并且此变量为字符串类型，PHP再获得此结果后并未不会进行解析（而且PHP是在服务端做解析的)，因为脚本语言按顺序执行且该变量为字符串类型，而在代码提交到用户的浏览器中时，html界面将<!--解析为注释内容，故会在源码中而不是显示出来
![image.png](../assets/2020-11-21-%E5%85%B3%E4%BA%8ELinux%E4%B8%AD$IFS%E7%89%B9%E6%AE%8A%E5%8F%98%E9%87%8F%E5%9C%A8%E6%B8%97%E9%80%8F%E6%B5%8B%E8%AF%95%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/image-da04c09152d04d27aa1e31be2931ddc0.png)

## 参考

[IFS-Linux Shell](https://bash.cyberciti.biz/guide/$IFS)