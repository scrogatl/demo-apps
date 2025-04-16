# Deployment instructions
1. Build MSK cluster, set up topics
2. Run package_deploy.py, fill in license key and bootstrap server
3. Build EC2 instance to serve as our kafka client
4. Drop kafka-msk.zip on the created instance and unzip
5. Open the new directory and run:
```
sudo docker build -t kafka-msk .
sudo docker run -d --rm kafka-msk
```