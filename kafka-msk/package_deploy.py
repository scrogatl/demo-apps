import os
import zipfile

def replace_text_in_file(file_path, old_text, new_text):
    """Replace old_text with new_text in the specified file."""
    with open(file_path, 'r') as file:
        file_data = file.read()
    
    file_data = file_data.replace(old_text, new_text)
    
    with open(file_path, 'w') as file:
        file.write(file_data)

def zip_directory(directory_path, zip_name):
    """Zip the specified directory."""
    zip_file_path = os.path.join(directory_path, zip_name)
    with zipfile.ZipFile(zip_file_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for foldername, subfolders, filenames in os.walk(directory_path):
            for filename in filenames:
                file_path = os.path.join(foldername, filename)
                if file_path != zip_file_path:  # Avoid zipping the zip file itself
                    arcname = os.path.relpath(file_path, directory_path)
                    zipf.write(file_path, arcname)

def main():
    # Take user inputs for the text replacements
    license_key = input("Enter New Relic license key: ")
    msk_broker = input("Paste your MSK broker's bootstrap server: ")

    # Define the paths to the files where replacements need to be made
    nrfile_path = 'newrelic/newrelic.yml' 
    javafile_path = 'src/main/java/com/kafkaMSK/KafkaMSK.java'

    # Replace text in the specified files
    replace_text_in_file(nrfile_path, "<INSERT_LICENSE_KEY>", license_key)
    replace_text_in_file(javafile_path, "<INSERT_BROKER>", msk_broker)

    # Zip the current directory
    current_directory = os.getcwd()
    zip_name = 'kafka-msk.zip'
    zip_directory(current_directory, zip_name)

    print(f"Directory zipped as {zip_name}")

if __name__ == "__main__":
    main()