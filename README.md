# Auvik Power BI Dashboard - Refresh Schedule Fix

Foobar is a Python library for dealing with word pluralization.

## Installation

*Note:* *I am making these changes in Power BI desktop using the `.pbix` template provided by Auvik's github*

After uploading the provided Auvik template and entering your credentials, follow these steps:

1. Make sure you are on the `Home` tab
2. Select `Transform Data` ![Home Tab](image.png)

3. You should now see a list of all the data sources on the left sidebar. Click on the source `Sites`. Then select `Advanced Editor` on your toolbar. ![Advanced Editor](image-1.png)
4. You will be presented with something that looks like this. ![Advanced Editor](image-4.png)
5. Find the folder corresponding to the source you are working on (i.e. Sites), and select the `new.pq` file. ![new.pq file](image-3.png)
6. Copy all of the contents and paste them back into your advanced editor screen on Power BI. It should look something like this - ![Advanced Editor 2](image-2.png).
7. Hit the green `Done` button in the bottom right corner, and verify that your data was refreshed correctly.
8. Repeat these steps for each source **EXCEPT THE FOLLOWING**:
    - `TIME`
    - `DATE`
    - `DOMAIN PREFIX OF MAIN SITE`
    - `REPORT START DATE`
    - `REPORT END DATE`
    - `AUVIK SERVER CLUSTER`


## Usage

```python
import foobar

# returns 'words'
foobar.pluralize('word')

# returns 'geese'
foobar.pluralize('goose')

# returns 'phenomenon'
foobar.singularize('phenomena')
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License

[MIT](https://choosealicense.com/licenses/mit/)