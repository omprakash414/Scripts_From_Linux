import smtplib
import argparse
from email.mime.text import MIMEText

def send_email(process_name):
    fromaddr = 'senders_email@gmail.com'  # Replace with your Gmail email address
    toaddrs = 'receivers_email@gmail.com'   # Replace with the recipient's email address

    subject = "Boss! Your Process is Finally Done 🎉"
    body = f"Hello Boss! Your process is finally done for {process_name}. You can check the output now. \n\nBest Regards,\nYours Kivi!"

    msg = MIMEText(body.encode('utf-8'), 'plain', 'utf-8')
    msg['Subject'] = subject
    msg['From'] = fromaddr
    msg['To'] = toaddrs

    username = 'senders_email@gmail.com'   # Replace with your Gmail email address
    password = 'Pass_Generated'         # Replace with the App Password generated for your Gmail account

    server = smtplib.SMTP('smtp.gmail.com', 587)
    server.starttls()
    server.login(username, password)
    server.sendmail(fromaddr, toaddrs, msg.as_string())
    server.quit()
    print(f"Email sent successfully for process '{process_name}'.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="This script sends an email notification when a specific process is completed.")
    parser.add_argument('process_name', type=str, help="The name of the process for which you want to notify.")
    args = parser.parse_args()

    send_email(args.process_name)
