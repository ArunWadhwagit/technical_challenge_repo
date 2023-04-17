def get_value_from_key(nested_object, key):
    # Split the key into a list of nested keys
    nested_keys = key.split('/')

    # Iterate through the nested keys to retrieve the final value
    value = nested_object
    for nested_key in nested_keys:
        value = value.get(nested_key)

    return value
object = {"a":{"b":{"c":"g"}}}
key = "a/b/c"
print(get_value_from_key(object, key))