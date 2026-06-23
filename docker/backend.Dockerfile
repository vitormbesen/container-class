FROM python:3.12-slim
WORKDIR /backend

COPY repository         ./repository
COPY run.py             .
COPY requirements.txt   .
COPY guess/             ./guess

RUN pip install -r requirements.txt
EXPOSE 5000
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]