APPNAME="blog"

sudo apt-get install -y ufw
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status

sudo apt-get -y update
sudo apt-get -y install python3 python3-venv python3-dev
sudo apt-get -y install supervisor nginx git


# Create a basic flask application
git clone https://github.com/samratrocks/flask-template.git 
mv flask-template blog
cd blog

python3 -m venv venv
source venv/bin/activate
pip install flask

pip install gunicorn
echo "export FLASK_APP=$APPNAME.py" >> ~/.profile

gunicorn -b localhost:8000 -w 4 $APPNAME:app


# Supervisor configuration.
cat <<EOL | sudo tee /etc/supervisor/conf.d/$APPNAME.conf
[program:$APPNAME]
command=/home/$USER/$APPNAME/venv/bin/gunicorn -b localhost:8000 -w 4 $APPNAME:app
directory=/home/$USER/$APPNAME
user=$USER
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
EOL


sudo supervisorctl reload
sudo rm /etc/nginx/sites-enabled/default

# Nginx configuration.
cat << EOL | sudo tee /etc/nginx/sites-enabled/$APPNAME 
server {
    # listen on port 80 (http)
    listen 80;
    server_name _;
    location / {
        # redirect any requests to the same URL but on https
        return 301 https://$host$request_uri;
    }
}
server {
    # listen on port 443 (https)
    listen 443 ssl;
    server_name _;

    # location of the self-signed SSL certificate
    ssl_certificate /home/$USER/$APPNAME/certs/cert.pem;
    ssl_certificate_key /home/$USER/$APPNAME/certs/key.pem;

    # write access and error logs to /var/log
    access_log /var/log/$APPNAME_access.log;
    error_log /var/log/$APPNAME_error.log;

    location / {
        # forward application requests to the gunicorn server
        proxy_pass http://localhost:8000;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /static {
        # handle static files directly, without forwarding to the application
        alias /home/$USER/$APPNAME/app/static;
        expires 30d;
    }
}
EOL

sudo service nginx reload

#``` Deploying application updates
# git pull                              # download the new version
# sudo supervisorctl stop $APPNAME     # stop the current server
# flask db upgrade                      # upgrade the database
# flask translate compile               # upgrade the translations
# sudo supervisorctl start $APPNAME    # start a new server
# ```
