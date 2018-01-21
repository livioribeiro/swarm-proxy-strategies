FROM python:3.6.4-alpine3.7

WORKDIR /app

COPY requirements.txt /app/
RUN pip install -r requirements.txt

COPY main.py /app/

CMD [ "python", "main.py" ]
