# Automatically hardens common vulnerabilities in Ubuntu 18.04
. ./harden.config
# Check if script is being run as root
#if [ "$EUID" -ne 0 ]
#  then echo "Please run as root"
#  exit
#fi

# Clear log file
rm $LOG

# Update and upgrade
read -p "Do you want to run update (y/n): " input
if [ "$input" != "${input#[Yy]}"  ];then
	apt-get update
	echo "updates ran" >> $LOG
else
	echo "no updates will be ran" >> $LOG
fi

echo "Do you want to upgrade software (y/n)"
read -p "Might be best to run later: " input
if [ "$input" != "${input#[Yy]}" ];then
	apt-get upgrade -y
	echo "Upgrade ran" >> $LOG
else
	echo "No upgrades will be ran" >> $LOG
fi

# Remove unnecessary packages

#apt-get remove -y nmap hydra john nikto netcat

# Install and enable firewall
read -p "install uncomplicated firewall ufw (y/n): " input
if [ "$input" != "${input#[Yy]}" ];then
	apt-get install -y ufw
	ufw enable
	echo "Installed and enabled ufw" >> $LOG
else 
	echo "Not installing firewall" >> $LOG
fi

# Locate all media files
echo "Start of media file search: " | tee $LOG
find / -iname '*.mp3' -o -iname '*.mp4' -o -iname '*.avi' -o -iname '*.mov' | tee $LOG
echo "End of media file search" | tee $LOG
# Password policy
# Update all user accounts with new max and min days for password
while IFS= read -r line; do
	echo "Text read from file: $line"

	chage -M $PASS_MAX_DAYS $line
	chage -m $PASS_MIN_DAYS $line

	echo "User $line max and min days were updated" >> $LOG

done < users.txt

# Set password complexity

# Set password complexity requirements
#cat <<EOF > /etc/security/pwquality.conf
#minlen = $MIN_LENGTH
#dcredit = $MIN_DIGITS
#ucredit = $MIN_UPPER
#lcredit = $MIN_LOWER
#ocredit = $MIN_SPECIAL
#EOF

# Set password history
# Set the number of passwords remembered
HISTORY=5

# Set password history requirements
sed -i "25s/.*/password requisite pam_pwquality.so retry=3 minlen=$MIN_LENGTH dcredit=$MIN_DIGITS ucredit=$MIN_UPPER lcredit=$MIN_LOWER ocredit=$MIN_SPECIAL/g" /etc/pam.d/common-password
sed -i "31s/.*/password requisite pam_pwhistory.so remember=$HISTORY use_authtok/g" /etc/pam.d/common-password
#password [success=1 default=ignore]  pam_unix.so obscure use_authok try_first_pass yescrypt sha512
#password requisite pam_deny.so
#password required pam_permit.so
#EOF
#
# Original
## here are the per-package modules (the "Primary" block)
#password        requisite                       pam_pwquality.so retry=3
#password        [success=2 default=ignore]      pam_unix.so obscure use_authtok try_first_pass yescrypt
#password        sufficient                      pam_sss.so use_authtok
# here's the fallback if no module succeeds
#password        requisite                       pam_deny.so
# prime the stack with a positive return value if there isn't one already;



# Set password lockout policy
# Set the number of attempts before lockout
ATTEMPTS=3

# Set the lockout duration
DURATION=600

# Set the lockout policy
# Disable null password
sed -i "17s/.*/auth	[success=2 default=ignore]	pam_unix.so/g" /etc/pam.d/common-auth 
echo "prevent logons with empty passwords" >> $LOG
#cat <<EOF > /etc/pam.d/common-auth
#auth    [success=2 default=ignore]      pam_unix.so nullok
#auth    [success=1 default=ignore]      pam_sss.so use_first_pass
#auth    requisite                       pam_deny.so
#auth    required                        pam_permit.so
#auth    optional                        pam_cap.so
#auth    required pam_tally2.so deny=3 unlock_time=600 onerr=succeed
#EOF

# Set password expiration

echo "Editting /etc/login.defs" >> $LOG
sed -i "165s/.*/PASS_MAX_DAYS $PASS_MAX_DAYS/g" /etc/login.defs # default 99999
echo "New user PASS_MAX_DAYS updated to $PASS_MAX_DAYS" >> $LOG
sed -i "166s/.*/PASS_MIN_DAYS $PASS_MAX_DAYS/g" /etc/login.defs # 0
echo "new user PASS_MIN_DAYS updated to $PASS_MIN_DAYS" >> $LOG
sed -i "167s/.*/PASS_WARN_AGE $PASS_WARN_AGE/g" /etc/login.defs # 7
echo "New User PASS_WARN_AGE updated to $PASS_WARN_AGE" >> $LOG
echo "Max, min, and warm age for new users updated" >> $LOG

# Shut off ssh Root Login
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
echo "Disabled ssh Root Login" >> $LOG

echo "Hardening script finished, search the log.txt file for more details and for file system paths"
