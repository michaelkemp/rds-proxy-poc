FROM python:3.9.5-slim-buster

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

EXPOSE 8080
COPY . /app

RUN apt-get -y update 
RUN apt-get -y install libpq-dev gcc
RUN pip install -r requirements.txt

CMD ["python", "main.py"]
