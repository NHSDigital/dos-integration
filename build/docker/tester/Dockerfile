FROM python:3.14
# Update Pip
RUN python -m pip install --upgrade pip
# Copy Python requirements
COPY assets/requirements.txt /
# Install Python requirements
RUN python -m pip install -r /requirements.txt --upgrade
