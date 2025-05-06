# ttl-management
this is a sample OMS schema to demonstrate TTL configurations in CRDB

## Clone the Repository
First install [git](https://git-scm.com) if you don't already have it.  Instructions for Mac, Windows or Linux can be found [here](https://www.atlassian.com/git/tutorials/install-git).  Then open a Mac Terminal or Windows PowerShell in your workspace folder (or wherever you keep your local repositories) and execute the following command.
```
git clone https://github.com/roachlong/ttl-management.git
cd ttl-management
git status
```


## Cockroach
If we're executing the PoC as a stand alone lab we can install and run a single node instance of cockroach on our laptops.  For Mac you can install CRDB with ```brew install cockroachdb/tap/cockroach```.  For Windows you can download and extract the latest binary from [here](https://www.cockroachlabs.com/docs/releases), then add the location of the cockroach.exe file (i.e. C:\Users\myname\AppData\Roaming\cockroach) to your Windows Path environment variable.

Then open a new Mac Terminal or PowerShell window and execute the following command to launch your single node database.
```
cockroach start-single-node --insecure --store=./data
```
Then open a browser to http://localhost:8080 to view the dashboard for your local cockroach instance


## Initial Schema
First we'll store the connection string as a variable in our terminal shell window.  On Mac variables are assigned like ```my_var="example"``` and on Windows we proceed the variable assignment with a $ symbol ```$my_var="example"```.
```
conn_str="postgresql://localhost:26257/defaultdb?sslmode=disable"
```

Then we'll execute the sql to create a sample schema and load some data into it.
```
cockroach sql --url "$conn_str" -f 01-initial-schema.sql
export conn_str="${conn_str/defaultdb/order_management}"
./02-apply-triggers.sh
cockroach sql --url "$conn_str" -f 03-load-initial-data.sql
```


## Add TTL Settings
Next we'll configure TTL on two of the tables using one of:
- **ttl_expire_after**: Sets a fixed interval after which rows expire.​
- **ttl_expiration_expression**: Allows for custom expressions to determine row expiration, offering more flexibility.​

It's important to note that adding ttl_expire_after to an existing table causes a full table rewrite, which can impact performance.  Using ttl_expiration_expression with an existing TIMESTAMPTZ column can mitigate this issue.

### Using ttl_expire_after:
```
cockroach sql --url "$conn_str" -e """
ALTER TABLE shipments
SET (ttl_expire_after = '30 days');
"""
```

Note the changes in the create statement for the shipments table, i.e. the new crdb_internal_expiration column and the with ttl clause
```
cockroach sql --url "$conn_str" -e """
show create table shipments;
"""

CREATE TABLE public.shipments (
	shipment_id UUID NOT NULL DEFAULT gen_random_uuid(),
	order_id UUID NOT NULL,
	carrier STRING NOT NULL,
	tracking_no STRING NULL,
	shipped_at TIMESTAMPTZ NULL,
	delivered_at TIMESTAMPTZ NULL,
	crdb_internal_expiration TIMESTAMPTZ NOT VISIBLE NOT NULL DEFAULT current_timestamp():::TIMESTAMPTZ + '30 days':::INTERVAL ON UPDATE current_timestamp():::TIMESTAMPTZ + '30 days':::INTERVAL,
	CONSTRAINT shipments_pkey PRIMARY KEY (shipment_id ASC),
	CONSTRAINT shipments_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id),
	UNIQUE INDEX shipments_tracking_no_key (tracking_no ASC),
	INDEX shipments_order_id_idx (order_id ASC)
) WITH (ttl = 'on', ttl_expire_after = '30 days':::INTERVAL)
```

### Using ttl_expiration_expression:
```
cockroach sql --url "$conn_str" -e """
ALTER TABLE orders 
SET (
  ttl_expiration_expression = '(updated_at + INTERVAL ''30 days'')'
);
"""
```

Note the changes in the create statement for the orders table, i.e. just the with ttl clause without any additional columns
```
cockroach sql --url "$conn_str" -e """
show create table orders;
"""

CREATE TABLE public.orders (
	order_id UUID NOT NULL DEFAULT gen_random_uuid(),
	customer_id UUID NOT NULL,
	order_status STRING NOT NULL DEFAULT 'pending':::STRING,
	total_amount DECIMAL(12,2) NOT NULL,
	placed_at TIMESTAMPTZ NOT NULL DEFAULT now():::TIMESTAMPTZ,
	updated_at TIMESTAMPTZ NOT NULL DEFAULT now():::TIMESTAMPTZ,
	CONSTRAINT orders_pkey PRIMARY KEY (order_id ASC),
	CONSTRAINT orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id),
	INDEX orders_customer_id_idx (customer_id ASC),
	INDEX orders_order_status_idx (order_status ASC),
	CONSTRAINT check_total_amount CHECK (total_amount >= 0:::DECIMAL)
) WITH (ttl = 'on', ttl_expiration_expression = e'(updated_at + INTERVAL \'30 days\')')
```


## Remove TTL Settings
In the event you want to quickly disable TTL on all tables you can use the following script, which will work regardless of the type of option used above.
```
./04-disable-ttl-settings.sh order_management
```
