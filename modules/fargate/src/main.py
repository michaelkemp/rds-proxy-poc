import os
import psycopg2
import random
import names

DBHOST = os.environ['DBHOST']
DBPORT = "5432"
DBNAME = os.environ['DBNAME']
DBUSER = os.environ['DBUSER']
DBPASS = os.environ['DBPASS']

def insertTable(person):
    try:
        connection = psycopg2.connect(user = DBUSER, password = DBPASS, host = DBHOST, port = DBPORT, database = DBNAME)
    except Exception as e:
        print("Connection Error: ", e)
        return

    try:    
        cursor = connection.cursor()
        postgres_insert_query = "INSERT INTO people (fullname, gender, phone, age) VALUES (%s,%s,%s,%s) RETURNING id"
        record_to_insert = (person["fullname"], person["gender"], person["phone"], person["age"])
        cursor.execute(postgres_insert_query, record_to_insert)
        id = cursor.fetchone()[0]
        connection.commit()
        count = cursor.rowcount
        print("Inserted ID: {} ".format(id))
        print(count, "Record inserted successfully into people table")

    except Exception as e:
        print("Failed to insert record into people table", e)


    if connection:
        cursor.close()
        connection.close()
        print("PostgreSQL connection is closed")


def selectTable():
    try:
        connection = psycopg2.connect(user = DBUSER, password = DBPASS, host = DBHOST, port = DBPORT, database = DBNAME)
    except Exception as e:
        print("Connection Error: ", e)
        return

    try:
        cursor = connection.cursor()
        postgres_select_query = "SELECT * FROM people ORDER BY id desc LIMIT 50"
        cursor.execute(postgres_select_query)
        people_records = cursor.fetchall()
        for p in people_records:
            print("{}, {}, {}, {}, {}".format(p[0],p[1],p[2],p[3],p[4]))

    except Exception as e:
        print("Failed to select records from people table", e)

    if connection:
        cursor.close()
        connection.close()
        print("PostgreSQL connection is closed")


def main():

    numbers = ["0","1","2","3","4","5","6","7","8","9"]
    mf = ["M","F"]

    # INSERTS
    for i in range(0,50):
        gender = random.choice(mf)
        if gender == "F":
            fullname = names.get_full_name(gender='female')
        else:
            fullname = names.get_full_name(gender='male')

        phone = ''.join(random.choice(numbers) for i in range(10))
        age = random.randint(15, 98)

        person = {
            "fullname": fullname,
            "gender": gender,
            "phone": phone,
            "age": age
        }

        insertTable(person)

    # SELECT
    selectTable()


if __name__ == "__main__":
    main()
