# Deployment

## UML Deployment

![uml_deployment](./src/uml_deployment.png)

## Devices

* Node 1 on Aliyun:
  * **Memory**: 1GB
  * **CPU**: 1 core
  * **Band**: 1Mbps

## Demo

**Demo website address** : http://aliyun.kinpzz.com:8000

Due to the demand of records  of web server in China, we can not use 80 port with domain name without records in government. So we use 8000 port instead.

## Nginx*([nginx.conf](/nginx.conf))*

In order to hide the service port of web service server and database server ports from clients, which is not secure to expose them, we use Nginx as a reverse proxy.

We configure the `nginx.conf`on`/etc/nginx/nginx.conf`by adding server configuration on `http` tag.

Here, we use Nginx as static resources server. Client can directly request static resources from the 8000 port and Nginx will directly reply. And Nginx relay the api request to 8081 port on localhost, which web service server is listening. This is more secure than directly expose the service port to public. 

PS: We directly deploy the Nginx on the node, but not deploy the Nginx server on docker because it needs to use the port other servers expose on the localhost. If we use docker, it will be a more complicated case, for it needs to connect different ports between these docker containers it denpends on.

PSS: We need to make sure the user of Nginx `www-data` have the access to the root dir configured  

## Docker CI/CD

Because we only have one node so we use docker container to simulate multiple nodes in the deployment. By using jenkins we can achieve continuous deployments on our node.

### Jenkins

We use jenkins docker image with maven and docker environment to do the ci jobs. Here we use the image lw96/java8-jenkins-maven-git-vim, which we can find on the docker hub.

```
docker run -d -p 0.0.0.0:8080:8080 -v /root/data:/jenkins \
-v /etc/localtime:/etc/localtime:ro \
-v /root/data/maven:/opt/maven \
-v /var/run/docker.sock:/var/run/docker.sock \
--name jenkins2 lw96/java8-jenkins-maven-git-vim
```

We use the volume to map maven from our host to docker container and map `docker.sock`. By share the `docker.sock`, the docker command executed on jenkins environment will be sent to host and executed. So we can create other docker containers or images on the host from the jenkins container. And this is our foundment of doing the ci/cd jobs.

And we use jenkins github plugin, which allow us to pull code from github once the trigger is active. (It is active when new code push to github or pull request is made)

### Database Server

To rebuild the latest image and run a new container depends on the image. Because the web service server relies on the db server. So it is not proper to rebuild it directly. So we have to stop the web service server `restful-server` container before stop `db` container to avoid connect error. And after build the new `db-server`image, we have to rebuild the `restful-server` image or it will occur error.

But later, in a proper and better way, we may use docker compose to declare the dependencies during building.

``` shell
docker stop restful-server
docker stop db
docker rm db
docker rmi db-server
docker build -t db-server 
docker run -d --name db db-server

docker rm restful-server
docker rmi kinpzz/restful-server
docker build -t kinpzz/restful-server ../docker-jenkins-test
docker run -d -p 127.0.0.1:8082:8082 --name restful-server --link db:db-server kinpzz/restful-server

```

### Web Service Server

Run the run.sh after jenkins scripts executing.

```shell
export MAVEN_HOME=/opt/maven
export JAVA_HOME=/opt/java/jdk1.8.0_112
export JENKINS_HOME=/jenkins

mvn package
docker stop restful-server
docker rm restful-server
docker rmi kinpzz/restful-server
docker build -t kinpzz/restful-server .
docker run -d -p 127.0.0.1:8082:8082 --name restful-server --link db:db-server kinpzz/restful-server
```

Here, we use in maven in jenkins docker in order to use the maven package cache to speed up the build process. And copy the `.war` to execute in the new images instead of build the maven project in the new docker. And use ``--link`` tag to connect the web service container with database server container by bridge. So the web service container can connect to the port of database server without exposing the port of database server to public.

Here, we can deploy the new version once we commit the code to GitHub.

### Web Page building

Run run.sh after jenkins scripts executing.

```shell
# for jenkins run shell
docker stop web-server
docker rm web-server
docker rmi web-server
docker build -t web-server .
docker run -d --name web-server web-server
# save to /home/kinpzz/webpage
docker cp web-server:/web-server/dist /jenkins/webpage
```

Here, we only generate the static web resources on the `web-server` container. The role of static resources server is played by Nginx. And then use the `docker cp` command to copy the static resources to the host, which the root in `Nginx.conf` is.



## Blog

Here you can refer to a chinese version on the blog : [Jenkins + Docker 实现项目持续部署](https://blog.kinpzz.com/2017/06/08/jenkins-docker-ci-cd/)

## TODO

Sometimes it faild by docker remove. May be it will be better to build the docker images on Aliyun and then pull them when we need to use it.

