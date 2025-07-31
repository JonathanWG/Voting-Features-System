mkdir feature_voting_system
cd feature_voting_system
python -m venv venv
source venv/bin/activate
pip install Django djangorestframework djangorestframework-simplejwt psycopg2-binary django-cors-headers redis django-redis
django-admin startproject feature_voting_backend .
python manage.py startapp users
python manage.py startapp features