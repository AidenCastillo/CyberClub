# Automatically hardens common vulnerabilities in Ubuntu 18.04
. ./harden.config
# Check if script is being run as root
#if [ "$EUID" -ne 0 ]
#  then echo "Please run as root"
#  exit
#fi

# Clear log file
rm -f $LOG

# Update and upgrade
read -p "Do you want to run update (y/n): " input
if [ "$input" != "${input#[Yy]}"  ];then
	apt-get update -y
	echo "Updates ran" | tee -a $LOG
else
	echo "No updates will be ran" | tee -a $LOG
fi

echo "Do you want to upgrade software (y/n)"
read -p "Might be best to run later: " input
if [ "$input" != "${input#[Yy]}" ];then
	apt-get upgrade -y
	echo "Upgrade ran" | tee -a $LOG
else
	echo "No upgrades will be ran" | tee -a $LOG
fi

# Remove unnecessary packages
echo "Unnecessary and prohibited packages will be removed based on the packages.txt file"
read -p "Do you want to remove prohibited packages (y/n):  " input
if [ "$input" != "${input#[Yy]}" ];then
	while IFS= read -r line; do
	       apt-get remove -y $line
	       echo "$line was removed" | tee -a $LOG
       done < packages.txt
else
	echo "No packages were removed" | tee -a $LOG
fi	
#apt-get remove -y nmap hydra john nikto netcat

# Install and enable firewall
read -p "install uncomplicated firewall ufw (y/n): " input
if [ "$input" != "${input#[Yy]}" ];then
	apt-get install -y ufw
	ufw enable
	echo "Installed and enabled ufw" | tee -a $LOG
else 
	echo "Not installing firewall" | tee -a $LOG
fi

# Auditing
read -p "Do you want to turn on auditd" input
if [ "$input" != "${input#[Yy]}" ];then
	apt install auditd
	systemctl restart auditd
	auditctl -w /etc/passwd -p wa -k passwd_changes
	echo "Auditd was turned on and restarted" | tee -a $LOG
else
	echo "Auditd was not turned on" | tee -a $LOG
fi

# Locate all media files
echo "Start of media file search: " | tee -a $LOG
find / -iname '*.mp3' -o -iname '*.mp4' -o -iname '*.avi' -o -iname '*.mov' 2>/dev/null | tee -a $LOG
echo "End of media file search" | tee -a $LOG

# Password policy
# Update all user accounts with new max and min days for password
while IFS= read -r line; do
	echo "Text read from file: $line"

	chage -M $PASS_MAX_DAYS $line
	chage -m $PASS_MIN_DAYS $line

	echo "User $line max and min days were updated" | tee -a $LOG

done < users.txt




# Set password complexity
sed -i "11s/.*/minlen = $PASS_MIN_LENGTH/g" /etc/security/pwquality.conf
sed -i "15s/.*/dcredit = $MIN_DIGITS/g" /etc/security/pwquality.conf
sed -i "20s/.*/ucredit = $MIN_UPPER/g" /etc/security/pwquality.conf
sed -i "25s/.*/lcredit = $MIN_LOWER/g" /etc/security/pwquality.conf
sed -i "30s/.*/ocredit = $MIN_SPECIAL/g" /etc/security/pwquality.conf
echo "Password complexity set" | tee -a $LOG

# Set password history requirements
sed -i "25s/.*/password requisite pam_pwquality.so retry=3 minlen=$PASS_MIN_LENGTH dcredit=$MIN_DIGITS ucredit=$MIN_UPPER lcredit=$MIN_LOWER ocredit=$MIN_SPECIAL/g" /etc/pam.d/common-password
sed -i "31s/.*/password requisite pam_pwhistory.so remember=$HISTORY use_authtok/g" /etc/pam.d/common-password
echo "Password history set" | tee -a $LOG

#password [success=1 default=ignore]  pam_unix.so obscure use_authok try_first_pass yescrypt sha512
#password requisite pam_deny.so
#password required pam_permit.so
#
# Original
## here are the per-package modules (the "Primary" block)
#password        requisite                       pam_pwquality.so retry=3
#password        [success=2 default=ignore]      pam_unix.so obscure use_authtok try_first_pass yescrypt
#password        sufficient                      pam_sss.so use_authtok
# here's the fallback if no module succeeds
#password        requisite                       pam_deny.so
# prime the stack with a positive return value if there isn't one already;



# Set account lockout policy
# Set the number of attempts before lockout
# Set the lockout duration

sed -i "10s/.*/auth required pam_securetty.so/g" /etc/pam.d/login
sed -i "14s/.*/auth required pam_tally2.so deny=$ATTEMPTS even_deny_root unlock_time=$DURATION/g" /etc/pam.d/login
echo "Lockout policy set to $ATTEMPTS attempts, unlock duration $DURATION seconds" | tee -a $LOG

# Disable null password
sed -i "17s/.*/auth	[success=2 default=ignore]	pam_unix.so/g" /etc/pam.d/common-auth 
echo "prevent logons with empty passwords" | tee -a $LOG
#cat <<EOF > /etc/pam.d/common-auth
#auth    [success=2 default=ignore]      pam_unix.so nullok
#auth    [success=1 default=ignore]      pam_sss.so use_first_pass
#auth    requisite                       pam_deny.so
#auth    required                        pam_permit.so
#auth    optional                        pam_cap.so
#auth    required pam_tally2.so deny=3 unlock_time=600 onerr=succeed
#EOF
#sed -i "27s/.*/auth required pam_tally2.so deny=$ATTEMPTS unlock_time=$DURATION onerr=succeed/g" /etc/pam.d/common-auth
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
