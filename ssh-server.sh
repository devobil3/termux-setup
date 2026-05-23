#!/data/data/com.termux/files/usr/bin/bash
pkg install openssh -y
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCpobqhor5JePAtFwnRW3Kjzt1OZgwrwDMqatBfnRHQ+YX5C4EChhOJtoWfwTBaA/kd07FL0moes3IqPGYU9OIXR4oCB2L3kHWvlCDhTheHHLKxOJErE+pbrY3iByCpNu+vDNiIdjyKGPe0gaRKRnQTd3uDATP7caR2cmc7WV//OJRne6cJmmjoaAEg0/hygYwm8PT3MU2g/LPxL3mHRB1N2/njK3+vJlo3WIbKqjTa6dTmAAMs1QdKgjKF+i8Use2iVY0N/QNAo0nywghEZzO4nwZaauvUPG373mF3eu+TN+mxdBbFTvoreq1jiz9WIm4b8WMJwCCATVKgb3xlYmjS050fDHAFQQRJtIfx8RQFqoNSvlUoptW6ZO0eftLxhopmwicipy4XW6mUa1hYZDkd6QAUt1saKuPWfIvOegq7ncJcicKTk8a7DctYpt+uG+Rz/oGH+3oEDLe6Yg6u2Gs4F/5EQn9bdwSqqUmCE69Djalgbe7y2CvWkXQbGl7D9G0= u0_a349@localhost" > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
sshd
