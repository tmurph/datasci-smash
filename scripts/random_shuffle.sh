# Randomly shuffle the contents of a file.
# Use a reproducible source of randomness.

filename="$1"
seed=${2:-42}

get_seeded_random()
{
  openssl enc -aes-256-cbc -pass pass:"$1" -nosalt </dev/zero 2>/dev/null
}

shuf "$filename" --random-source=<(get_seeded_random "$seed")
