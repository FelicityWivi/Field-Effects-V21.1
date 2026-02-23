def generate_unique_id(digits = 8)
  random_ints = ("0".."9").to_a.sample(digits)
  random_letters = ("a".."z").to_a.sample(digits) + ("A".."Z").to_a.sample(digits)
  (random_ints + random_letters).shuffle!.join
end

def debugControl
  $DEBUG && Input.press?(Input::CTRL)
end