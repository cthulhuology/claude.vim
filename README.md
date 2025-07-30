# claude.vim
Claude 4 code gen vim plugin

# Getting Started
Install the latest aws cli tool

```shell
  $ curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
```
And clone this repo into your ~/.vim/plugin directory

```shell
  mkdir -p ~/.vim/plugin
  cd ~/.vim/plugin
  git clone https://github.com/cthulhuology/claude.vim.git
```

Then assuming you've enabled Claude 4 in Frankfurt (my closest region).
You can do something like:

```shell
  vim test.py
```

And edit the file

```python
  # generate fizzbuz
```

And with the cursor on the comment in visual mode and hit Ctrl-g and it should generate your code.

