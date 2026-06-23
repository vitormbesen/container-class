FROM python:3.12-slim
WORKDIR /backend

COPY requirements.txt   .
RUN pip install -r requirements.txt

# singleton pattern
COPY run.py             .
# abstraction, less likely to change
COPY repository         ./repository

# game source code
COPY guess/             ./guess

EXPOSE 5000
ENTRYPOINT ["flask", "run", "--host=0.0.0.0", "--port=5000"]