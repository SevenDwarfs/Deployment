docker stop restful-server
docker stop db
docker rm db
docker rmi db-server
docker build -t db-server .
docker run -d --name db db-server

docker rm restful-server
docker rmi kinpzz/restful-server
docker build -t kinpzz/restful-server ../docker-jenkins-test
docker run -d -p 127.0.0.1:8082:8082 --name restful-server --link db:db-server kinpzz/restful-server
