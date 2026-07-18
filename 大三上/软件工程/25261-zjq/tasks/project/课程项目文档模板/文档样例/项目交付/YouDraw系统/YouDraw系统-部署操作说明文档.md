# 前端

使用`npm run build`获取构建后的静态文件，目录在`dist`目录下

将`dist`目录下的文件放在要进行部署的文件夹下，使用代理服务器`nginx`进行访问。

前端向后端发起请求，用的`url`是`/api/XXX`，总是以`/api`开头的，因此在`nginx`配置文档中，对`/api`进行代理转发

```nginx
 location /api {
            proxy_pass http://localhost:8080/;  # 监听的端口号为8080
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Credentials' 'true';
        }
```

# 后端

主要的配置文档在`src/main/resources/jdbc.properties`中，其中放了`mysql`相关配置

```properties
jdbc.driverClassName=com.mysql.cj.jdbc.Driver  # mysql 8.0以上
jdbc.url=jdbc:mysql://localhost:3306/moment?  useUnicode=true&characterEncoding=gbk&useSSL=false&serverTimezone=Asia/Shanghai  #moment是数据库名称
jdbc.username=root  #用户名
jdbc.password=1161792932@qq  #用户密码
```

使用的时候删除上方`#`注释

七牛云相关配置在`config.properties`中，其中`AccessKe`,`SevretKey`以及`uri`目前都是我的，后续可以替换成项目正式的

编译执行使用`maven clean`以及`maven package`，在`target`中获得编译后`war`

采用`tomcat`进行部署，将其放入`tomcat`中的目录下，自行定义端口号，要和前端的端口号和转发相匹配

# 数据库

执行`sql`

