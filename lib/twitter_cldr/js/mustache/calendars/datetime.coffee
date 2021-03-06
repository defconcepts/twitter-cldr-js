# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

class TwitterCldr.DateTimeFormatter
  constructor: ->
    @tokens = `{{{tokens}}}`
    @weekday_keys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
    @methods = # ignoring u, l, g, j, A
      'G': 'era'
      'y': 'year'
      'Y': 'year_of_week_of_year'
      'Q': 'quarter'
      'q': 'quarter_stand_alone'
      'M': 'month'
      'L': 'month_stand_alone'
      'w': 'week_of_year'
      'W': 'week_of_month'
      'd': 'day'
      'D': 'day_of_month'
      'F': 'day_of_week_in_month'
      'E': 'weekday'
      'e': 'weekday_local'
      'c': 'weekday_local_stand_alone'
      'a': 'period'
      'h': 'hour'
      'H': 'hour'
      'K': 'hour'
      'k': 'hour'
      'm': 'minute'
      's': 'second'
      'S': 'second_fraction'
      'z': 'timezone'
      'Z': 'timezone'
      'v': 'timezone_generic_non_location'
      'V': 'timezone_metazone'

  format: (obj, options) ->
    format_token = (token) =>
      result = ""

      switch token.type
        when "pattern"
          this.result_for_token(token, obj)
        else
          token.value.replace(/'([^']+)'/g, '$1')

    tokens = this.get_tokens(obj, options)
    (format_token(token) for token in tokens).join("")

  get_tokens: (obj, options) ->
    format = options.format || "date_time"
    type = options.type || "default"

    if format == "additional"
      @tokens["date_time"][format][this.additional_format_selector().find_closest(options.type)]
    else
      @tokens[format][type]

  result_for_token: (token, date) ->
    this[@methods[token.value[0]]](date, token.value, token.value.length)

  additional_format_selector: ->
    new TwitterCldr.AdditionalDateFormatSelector(@tokens["date_time"]["additional"])

  @additional_formats: ->
    new TwitterCldr.DateTimeFormatter().additional_format_selector().patterns()

  era: (date, pattern, length) ->
    switch length
      when 0
        choices = ["", ""]
      when 1, 2, 3
        choices = TwitterCldr.Calendar.calendar["eras"]["abbr"]
      else
        choices = TwitterCldr.Calendar.calendar["eras"]["name"]

    index = if (date.getFullYear() < 0) then 0 else 1
    result = choices[index]

    if result? then result else this.era(date, pattern[0..-2], length - 1)

  year: (date, pattern, length) ->
    year = date.getFullYear().toString()

    if length == 2
      if year.length != 1
        year = year.slice(-2)

    if length > 1
      year = ("0000" + year).slice(-length)

    year

  year_of_week_of_year: (date, pattern, length) ->
    throw 'not implemented'

  day_of_week_in_month: (date, pattern, length) -> # e.g. 2nd Wed in July
    throw 'not implemented'

  quarter: (date, pattern, length) ->
    # the bitwise OR is used here to truncate the decimal produced by the / 3
    quarter = ((date.getMonth() / 3) | 0) + 1

    switch length
      when 1
        quarter.toString()
      when 2
        ("0000" + quarter.toString()).slice(-length)
      when 3
        TwitterCldr.Calendar.quarters({format: 'format', names_form: 'abbreviated'})[quarter]
      when 4
        TwitterCldr.Calendar.quarters({format: 'format', names_form: 'wide'})[quarter]

  quarter_stand_alone: (date, pattern, length) ->
    quarter = (date.getMonth() - 1) / 3 + 1

    switch length
      when 1
        quarter.toString()
      when 2
        ("0000" + quarter.toString()).slice(-length)
      when 3
        throw 'not yet implemented (requires cldr\'s "multiple inheritance")'
      when 4
        throw 'not yet implemented (requires cldr\'s "multiple inheritance")'
      when 5
        TwitterCldr.Calendar.quarters({format: 'stand-alone', names_form: 'narrow'})[quarter]

  month: (date, pattern, length) ->
    month = date.getMonth()
    month_str = (month + 1).toString()

    switch length
      when 1
        month_str
      when 2
        ("0000" + month_str).slice(-length)
      when 3
        TwitterCldr.Calendar.months({format: 'format', names_form: 'abbreviated'})[month]
      when 4
        TwitterCldr.Calendar.months({format: 'format', names_form: 'wide'})[month]
      when 5
        throw 'not yet implemented (requires cldr\'s "multiple inheritance")'
      else
        throw "Unknown date format"

  month_stand_alone: (date, pattern, length) ->
    month = date.getMonth()
    month_str = (month + 1).toString()

    switch length
      when 1
        month_str
      when 2
        ("0000" + month_str).slice(-length)
      when 3
        TwitterCldr.Calendar.months({format: 'stand-alone', names_form: 'abbreviated'})[month]
      when 4
        TwitterCldr.Calendar.months({format: 'stand-alone', names_form: 'wide'})[month]
      when 5
        TwitterCldr.Calendar.months({format: 'stand-alone', names_form: 'narrow'})[month]
      else
        throw "Unknown date format"

  day: (date, pattern, length) ->
    switch length
      when 1
        date.getDate().toString()
      when 2
        ("0000" + date.getDate().toString()).slice(-length)

  weekday: (date, pattern, length) ->
    key = @weekday_keys[date.getDay()]

    switch length
      when 1, 2, 3
        TwitterCldr.Calendar.weekdays({format: 'format', names_form: 'abbreviated'})[key]
      when 4
        TwitterCldr.Calendar.weekdays({format: 'format', names_form: 'wide'})[key]
      when 5
        TwitterCldr.Calendar.weekdays({format: 'stand-alone', names_form: 'narrow'})[key]

  weekday_local: (date, pattern, length) ->
    # "Like E except adds a numeric value depending on the local starting day of the week"
    # CLDR does not contain data as to which day is the first day of the week, so we will assume Monday (Ruby default)
    switch length
      when 1, 2
        day = date.getDay()
        if day == 0 then "7" else day.toString()
      else
        this.weekday(date, pattern, length)

  weekday_local_stand_alone: (date, pattern, length) ->
    switch length
      when 1
        this.weekday_local(date, pattern, length)
      else
        this.weekday(date, pattern, length)

  period: (time, pattern, length) ->
    if time.getHours() > 11
      TwitterCldr.Calendar.periods({format: 'format', names_form: 'wide'})["pm"]
    else
      TwitterCldr.Calendar.periods({format: 'format', names_form: 'wide'})["am"]

  hour: (time, pattern, length) ->
    hour = time.getHours()

    switch pattern[0]
      when 'h'
        if hour > 12
          hour = hour - 12
        else if hour == 0
          hour = 12
      when 'K'
        if hour > 11
          hour = hour - 12
      when 'k'
        if hour == 0
          hour = 24

    if length == 1
      hour.toString()
    else
      ("000000" + hour.toString()).slice(-length)

  minute: (time, pattern, length) ->
    if length == 1
      time.getMinutes().toString()
    else
      ("000000" + time.getMinutes().toString()).slice(-length)

  second: (time, pattern, length) ->
    if length == 1
      time.getSeconds().toString()
    else
      ("000000" + time.getSeconds().toString()).slice(-length)

  second_fraction: (time, pattern, length) ->
    if length > 6
      throw 'can not use the S format with more than 6 digits'

    ("000000" + Math.round(Math.pow(time.getMilliseconds() * 100.0, 6 - length)).toString()).slice(-length)

  timezone: (time, pattern, length) ->
    offset = time.getTimezoneOffset()

    hours = ("00" + (Math.floor(Math.abs(offset) / 60)).toString()).slice(-2)
    minutes = ("00" + (Math.abs(offset) % 60).toString()).slice(-2)
    sign = if offset > 0 then "-" else "+" # timezone sign is opposite to offset sign

    offsetString = sign + hours + ":" + minutes

    switch length
      when 1, 2, 3
        offsetString
      else
        "UTC" + offsetString

  timezone_generic_non_location: (time, pattern, length) ->
    throw 'not yet implemented (requires timezone translation data")'