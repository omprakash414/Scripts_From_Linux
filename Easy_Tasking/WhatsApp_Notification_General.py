from twilio.rest import Client

def send_whatsapp():
    # Twilio credentials
    account_sid = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'  # Replace with your Twilio Account SID
    auth_token = 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy'    # Replace with your Twilio Auth Token
    twilio_whatsapp_number = 'whatsapp:+1234567789'  # Twilio sandbox number for WhatsApp

    # Recipient's WhatsApp number
    to_whatsapp_number = 'whatsapp:+your_number'  # Replace with your WhatsApp number

    # Message content
    message_body = (
        "Boss! Your Process is Finally Done 🎉\n\n"
        "\n\n"
        "❤️ -- Yours, Kivi"
    )

    # Twilio client setup
    client = Client(account_sid, auth_token)

    # Send WhatsApp message
    message = client.messages.create(
        body=message_body,
        from_=twilio_whatsapp_number,
        to=to_whatsapp_number
    )
    print(f"WhatsApp message sent with SID: {message.sid}")

if __name__ == "__main__":
    send_whatsapp()
