$ ->
  tasks = []
  interval = null

  html_by_task = (task) ->
    arr = []
    arr.push("<tr id=\"entry_for_#{task.id}\">")

    arr.push('<td>')
    arr.push(task.id)
    arr.push('</td>')

    arr.push('<td>')
    arr.push(task.from)
    arr.push('</td>')

    arr.push('<td>')
    arr.push(task.to)
    arr.push('</td>')

    arr.push('<td class="status">')
    arr.push(task.status)
    arr.push('</td>')

    arr.push('<td>')
    arr.push(task.duration)
    arr.push('</td>')

    arr.push('</tr>')

    arr.join('')

  start_poller = ->
    clearInterval(interval) if interval
    interval = window.setInterval( ->
      console.log 'Checking state'
      for task in tasks
        $.ajax(
          url: "jobs/#{task.id}.json",
          method: 'GET',
          content: 'application/json',
          success: (data) ->
            update_entry_status data
          ,
          error: ->
            console.log 'ERROR!'
        )
    , 1000)

  update_entry_status = (task) ->
    $("#entry_for_#{task.id} td.status").text(task.status)

  create_new_task_entry = (task) ->
    $('#results').find('tbody')
      .prepend(html_by_task(task))

    # item = { id: 'foobar', status: 'Error!' }
    # update_entry_status item

  $('#btnSend').on 'click', ->
    from = $('#txtFrom').val()
    to = $('#txtTo').val()
    alert "From #{from} - To #{to}"

    $.ajax(
      url: 'jobs.json',
      method: 'POST',
      content: 'application/json',
      success: (result) ->
        id = result.id
        alert("Cool! #{id}")
        tasks.push result
        create_new_task_entry result
        start_poller()
      ,
      error: (error) ->
        alert('Error!')
    )
