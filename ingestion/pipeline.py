import os, dlt
from sec_source import sec_edgar
p = dlt.pipeline("sec_edgar", destination=dlt.destinations.duckdb(os.environ.get("WAREHOUSE_PATH", "warehouse.duckdb")), dataset_name="raw")
if __name__ == "__main__": print(p.run(sec_edgar()))
