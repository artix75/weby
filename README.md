# Weby

Weby lets you easily handle and generate HTML, XHTML or XML code in Ruby.
It can be used both as a templating system and as a programmatic HTML generator.
You can even mix templating and programmatic HTML, so you're free to use it as you like.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'weby'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install weby

## Usage

Here's some example:


```ruby
require 'rubygems'
require 'weby'

#Loading a template

html = <<EOS
<div id="main">
    <h1>Hello</h1>
    <ul>
	<li></li>
    </ul>
    <select>
	<option></option>
    </select>
    <table>
	<tr>
	    <td></td>
	</tr>
    </table>
    <span wby-if="num.even?">An even number</span>
    <span wby-if="num.odd?">An odd number</span>
</div>
EOS

h = HTML.parse html

puts h

```

Now let's see some evaluation feature:

```ruby

num = 2
h.evaluate binding: binding
puts h.to_html

```
This will output:

```html
    <div id="main">
        <h1>Hello</h1>
        <ul>
            <li>
        </ul>
        <select>
            <option></option>
        </select>
        <table>
            <tr>
                <td></td>
            </tr>
        </table>
        <span>An even number</span>
        
    </div>
```

Now let's manipulate HTML elements:

```ruby

h.find('#main').append {
    h2{'Title'}
}
h.append {
    div(id: 'body'){'World'}
}
h.find('h1').add_class 'header'
h.find('h1,h2').add_class 'title'
puts h.to_html

```

Output:

```html
<div id="main">
    <h1 class="header title">Hello</h1>
    <ul>
        <li>
    </ul>
    <select>
        <option></option>
    </select>
    <table>
        <tr>
            <td></td>
        </tr>
    </table>
    <span>An even number</span>
    
    <h2 class="title">Title</h2>
</div>
<div id="body">World</div>
```

We can also use some element as a template for given data:

```ruby
li = h.find 'ul li'
li.as_template %w(Apple Banana)
puts h
```

Output:

```html

...

<ul>
    <li>Apple</li>
    <li>Banana</li>
</ul>

...

```

More complex templating:

```ruby
o = h.find 'option'
o.as_template [
    {value: '#fff', content: :white},
    {value: '#000', content: :black}
]
```

Will produce:

```html

...

<select>
    <option value="#fff">white</option>
    <option value="#000">black</option>
</select>

...

```

```ruby
tr = h.find 'tr'
tr.as_template [
    {
        id: 'user-1',
        select: {td: {content: 'User 1'}}
    },
    {
        id: 'user-2',
        select: {td: {content: 'User 2'}}
    },
]
```

```html
<table>
    <tr id="user-1">
        <td>User 1</td>
    </tr>
    <tr id="user-2">
        <td>User 2</td>
    </tr>
</table>
```

We can also easily manipulate style and data:

```ruby
main = h.find '#main'
main.style :width, '800px'
main.style height: '100%', border: '1px solid'
main.data 'pageid', '1'
main.data userid: 1, username: 'admin'
```

```html
<div id="main" style="width: 800px; height: 100%; border: 1px solid" data-pageid="1" data-userid="10" data-username="artix">

...

</div>
```

## Contributing

1. Fork it ( https://github.com/artix75/weby/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
