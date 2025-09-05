import os
import pyodbc
import logging
from flask import Flask, render_template, jsonify

# --- Flask App Initialization ---
app = Flask(__name__)

# --- Database Configuration ---
DB_SERVER = os.environ.get('DB_SERVER', 'mssql') # Use the service name from docker-compose
DB_DATABASE = os.environ.get('DB_DATABASE', 'AdventureWorks')
DB_USERNAME = os.environ.get('DB_USERNAME', 'sa')
DB_PASSWORD = os.environ.get('DB_PASSWORD')

# --- Logging Configuration ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

def get_db_connection():
    """Establishes a connection to the SQL Server database."""
    connection_string = (
        f'DRIVER={{ODBC Driver 17 for SQL Server}};'
        f'SERVER={DB_SERVER};'
        f'DATABASE={DB_DATABASE};'
        f'UID={DB_USERNAME};'
        f'PWD={DB_PASSWORD};'
        f'TrustServerCertificate=yes;' # Necessary for self-signed certs in Docker
    )
    try:
        logging.info(f"Attempting to connect to {DB_DATABASE} on {DB_SERVER} with {DB_USERNAME} user...")
        cnxn = pyodbc.connect(connection_string, autocommit=False) # autocommit=False for blocking scenario
        logging.info("Database connection successful.")
        return cnxn
    except pyodbc.Error as ex:
        sqlstate = ex.args[0]
        logging.error(f"Database connection failed: {sqlstate}")
        raise

def execute_query(proc_name, params=()):
    """Executes a stored procedure and returns the results as a JSON string."""
    cnxn = None
    try:
        cnxn = get_db_connection()
        cursor = cnxn.cursor()
        
        # Construct the full stored procedure call
        # The placeholder '?' is standard for pyodbc
        param_placeholders = ','.join(['?'] * len(params))
        sql_query = f"{{CALL {proc_name}({param_placeholders})}}"

        logging.info(f"Executing stored procedure: {proc_name} with params: {params}")
        
        # pyodbc expects params as a tuple, even for a single param
        if isinstance(params, (str, int)):
            params = (params,)

        cursor.execute(sql_query, params)

        rows = cursor.fetchall()
        columns = [column[0] for column in cursor.description]
        results = [dict(zip(columns, row)) for row in rows]
        
        return jsonify(results)

    except pyodbc.Error as e:
        logging.error(f"Error executing query {proc_name}: {e}")
        return jsonify({"error": f"Database error: {e}"}), 500
    finally:
        if cnxn:
            cnxn.close()
            logging.info("Database connection closed.")


@app.route('/')
def index():
    logging.info("Serving index.html")
    return render_template('index.html')

# --- Standard Query Routes ---

@app.route('/query/normal')
def normal_query():
    # A typical customer ID from AdventureWorks
    customer_id = 29847
    return execute_query('GetRecentCustomerOrders', (customer_id,))

@app.route('/query/wait')
def wait_query():
    # This procedure takes no parameters
    return execute_query('GenerateSlowSummaryReport')

@app.route('/query/missing_index')
def missing_index_query():
    # A common last name
    last_name = 'Smith'
    return execute_query('FindPersonByLastName', (last_name,))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
