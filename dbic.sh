#!/bin/bash

echo Using database lenio. Please enter the root password of the mysql database:
read PASSWORD

dbicdump -o dump_directory=./lib -o components='["InflateColumn::DateTime"]' Lenio::Schema 'dbi:mysql:dbname=lenio' root $PASSWORD

