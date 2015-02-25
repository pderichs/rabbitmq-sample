$ ->
  create_new_task_entry = (task) ->
    arr = []

    arr.push('<tr>')

    arr.push('<td>')
    arr.push(task.id)
    arr.push('</td>')

    arr.push('<td>')
    arr.push(task.from)
    arr.push('</td>')

    arr.push('<td>')
    arr.push(task.to)
    arr.push('</td>')

    arr.push('<td>')
    arr.push('Waiting for result')
    arr.push('</td>')

    arr.push('<td>')
    #arr.push('')
    arr.push('</td>')

    arr.push('</tr>')

    $('#results').find('tbody')
      .prepend(arr.join(''))

  $('#btnSend').on 'click', ->
    from = $('#txtFrom').val()
    to = $('#txtTo').val()
    alert "From #{from} - To #{to}"

    $.ajax(
      url: 'jobs.json',
      method: 'POST',
      content: 'application/json',
      # data: 'json',
      success: (result) ->
        id = result.id
        alert("Cool! #{id}")

        create_new_task_entry result
      ,
      error: (error) ->
        alert('Error!')
    )
