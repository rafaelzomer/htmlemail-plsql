# htmlemail-plsql
a package writen on plsql to easyly send personalized emails

## Quick Start
1. Copy code from [here](https://github.com/rafaelzomer/htmlemail-plsql/blob/master/htmlemail-plsql.sql) and run on your database.
2. Use it like the example below: 
```sql
BEGIN
    HTML_EMAIL.SEND(
        send_host => 'smtp.email.com',
        send_login => 'email@email.com',
        send_password => 'emailpassword',
        send_to => 'email@email.com',
        email_title => 'Email Title',
        email_body => '<email> Hello Email </email>'
    );
END;
```

## Documentation
[Wiki](https://github.com/rafaelzomer/htmlemail-plsql/wiki)

## Legal and Trademarks
 * Oracle is a registered trademark of Oracle Corporation.
 * PL/SQL is a trademark of Oracle Corporation.
