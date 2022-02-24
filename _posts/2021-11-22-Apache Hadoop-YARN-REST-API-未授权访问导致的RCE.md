前些日子，阿里云安全团队在野捕获Hadoop Yarn RPC未授权访问漏洞

分析文章网上应该传遍了，在这里就不写了(我是懒比，大家都懂)，做了个poc和exp，在这里写个简单的复现流程。

首先存在该漏洞的页面如下，默认端口为8088有很多环境中端口号可能有变:

![index.png](../assets/2021-11-22-Apache%20Hadoop-YARN-REST-API-%E6%9C%AA%E6%8E%88%E6%9D%83%E8%AE%BF%E9%97%AE%E5%AF%BC%E8%87%B4%E7%9A%84RCE/index-8fb5a86fb7c4460aa2e5b9e3a7f2a3c8.png)

fofa指纹如下:

```
app="APACHE-hadoop-YARN"
```

![image.png](../assets/2021-11-22-Apache%20Hadoop-YARN-REST-API-%E6%9C%AA%E6%8E%88%E6%9D%83%E8%AE%BF%E9%97%AE%E5%AF%BC%E8%87%B4%E7%9A%84RCE/image-4b91f23a17f54628b6c3db09a9fcc34d.png)

POC:

![poc.png](../assets/2021-11-22-Apache%20Hadoop-YARN-REST-API-%E6%9C%AA%E6%8E%88%E6%9D%83%E8%AE%BF%E9%97%AE%E5%AF%BC%E8%87%B4%E7%9A%84RCE/poc-7e604727829045f98ab0828d9a69c643.png)

EXP:

![exp.png](../assets/2021-11-22-Apache%20Hadoop-YARN-REST-API-%E6%9C%AA%E6%8E%88%E6%9D%83%E8%AE%BF%E9%97%AE%E5%AF%BC%E8%87%B4%E7%9A%84RCE/exp-05ed20adc1164c9e862470cac4dff1d1.png)

Getshell:

![image-20211123114121470](../assets/2021-11-22-Apache%20Hadoop-YARN-REST-API-%E6%9C%AA%E6%8E%88%E6%9D%83%E8%AE%BF%E9%97%AE%E5%AF%BC%E8%87%B4%E7%9A%84RCE/image-20211123114121470.png)

相关POC与EXP已经上传至Github:

[Apache Hadoop YARN REST API Unauthorized RCE EXP&POC](https://github.com/N0b1ta/Bit-Cannon/tree/master/Apache/Hadoop/YARN/hadoop-yarn-rest-api-unauth)



相关文章:

[【漏洞预警】Hadoop Yarn RPC未授权访问漏洞](https://cn-sec.com/archives/632117.html)

[修复方式](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-common/SecureMode.html#Configuration)

[Apache Hadoop YARN API 手册](https://hadoop.apache.org/docs/current/hadoop-yarn/hadoop-yarn-common/apidocs/org/apache/hadoop/yarn/ipc/YarnRPC.html)