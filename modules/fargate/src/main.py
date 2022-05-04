import os
import psycopg2
import random
import string



DBHOST = os.environ['DBHOST']
DBPORT = "5432"
DBNAME = os.environ['DBNAME']
DBUSER = os.environ['DBUSER']
DBPASS = os.environ['DBPASS']


def insertTable(connection, cursor, person):
    try:
        connection = psycopg2.connect(user = DBUSER, password = DBPASS, host = DBHOST, port = DBPORT, database = DBNAME)
        cursor = connection.cursor()

        postgres_insert_query = "INSERT INTO people (fullname, gender, phone, age) VALUES (%s,%s,%s,%s) RETURNING id"
        record_to_insert = (person["fullname"], person["gender"], person["phone"], person["age"])
        cursor.execute(postgres_insert_query, record_to_insert)
        id = cursor.fetchone()[0]

        connection.commit()
        count = cursor.rowcount
        print("Inserted ID: {} ".format(id))
        print(count, "Record inserted successfully into people table")

    except (Exception, psycopg2.Error) as error:
        print("Failed to insert record into people table", error)


def selectTable(connection, cursor):
    try:
        postgres_select_query = "SELECT * FROM people"
        cursor.execute(postgres_select_query)
        people_records = cursor.fetchall()

        for p in people_records:
            print("id:{},fullname:{},gender:{},phone:{},age:{}".format(p[0],p[1],p[2],p[3],p[4]))

    except (Exception, psycopg2.Error) as error:
        print("Failed to select records from people table", error)


def main():

    letters = string.ascii_lowercase
    numbers = string.digits
    mf = ["M","F"]

    try:
        connection = psycopg2.connect(user = DBUSER, password = DBPASS, host = DBHOST, port = DBPORT, database = DBNAME)
        cursor = connection.cursor()

        # INSERTS
        for i in range(0,50):
            first = ''.join(random.choice(letters) for i in range(7))
            last = ''.join(random.choice(letters) for i in range(9))
            gender = random.choice(mf)
            phone = ''.join(random.choice(numbers) for i in range(10))
            age = random.randint(15, 98)
            person = {
                "fullname": first.capitalize() + " " + last.capitalize(),
                "gender": gender,
                "phone": phone,
                "age": age
            }
            insertTable(connection, cursor, person)

        # SELECT
        selectTable(connection, cursor)

    except Exception as e:
        print("Error: ", e)

    finally:
        # closing database connection.
        if connection:
            cursor.close()
            connection.close()
            print("PostgreSQL connection is closed")


if __name__ == "__main__":
    main()
