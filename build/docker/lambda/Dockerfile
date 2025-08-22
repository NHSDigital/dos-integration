FROM public.ecr.aws/lambda/python:3.13-arm64
# Update Pip
RUN python -m pip install --upgrade pip
# Copy Python requirements
COPY assets/requirements.txt /
# Install Python requirements
RUN pip install -r /requirements.txt --upgrade
# Copy function code
ADD assets/app.tar.gz "/var/task"
# Set the CMD to your handler
CMD [ "CMD_TO_REPLACE" ]
