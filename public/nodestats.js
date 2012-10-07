
//date helpers

function dateToStamp(date) {
    return Math.round(date/1000);
}

function stampToDate(val) {
    var d = new Date();
    d.setTime (val*1000);
    return d;
}

function getStart() {
    return dateToStamp($('#from').datetimepicker('getDate'));
}

function getLength() {
    return (dateToStamp($('#to').datetimepicker('getDate'))-getStart())/3600;
}

//stat generation

function SortByName(a, b){
  var aName = a[0];
  var bName = b[0];
  return ((aName < bName) ? -1 : ((aName > bName) ? 1 : 0));
}

function SortByVal(a, b){
  var aName = a[1];
  var bName = b[1];
  return ((aName < bName) ? -1 : ((aName > bName) ? 1 : 0));
}

//request raverage or runique
function drawRouterBars(type) {
    st = getStart();
    len = getLength();
    $('#status').html('Bitte warten... (Kann sich nur um Tage handeln)');

    $.get('/json',{type: type, start: st, length: len}, function(data) {
        data.sort(SortByVal);

        // Create the data table.
        var ch = new google.visualization.DataTable();
        ch.addColumn('string', 'Router');
        ch.addColumn('number', 'Clients');
        ch.addRows(data);

        // Set chart options
        var options = {title:'Anzahl unterschiedliche Clients',
                       height: data.length*15,
                       vAxis: {textStyle: {fontSize: 12}}
        };

        // Instantiate and draw our chart, passing in some options.
        var chart = new google.visualization.BarChart(document.getElementById('chart'));
        chart.draw(ch, options);
        $('#status').html('');
    })
}

function drawRouterLoad(router) {
    st = getStart();
    len = getLength();
    $('#status').html('Bitte warten...');

    $.get('/json',{type: 'rload', obj: router, start: st, length: len}, function(data) {
        data.unshift(['Zeit','Clients'])

        // Create the data table.
        var ch = new google.visualization.arrayToDataTable(data);

        // Set chart options
        var options = {title:'Router Auslastungsgraph',height: 900};

        // Instantiate and draw our chart, passing in some options.
        var chart = new google.visualization.LineChart(document.getElementById('chart'));
        chart.draw(ch, options);
        $('#status').html('');
    })
}

function drawTimeline(router, type) {
//TODO: a bit hacked linechart
}


//Datetimepicker stuff

function dateToday() {
    var d = new Date();
    return new Date(d.getFullYear(),d.getMonth(),d.getDate());
}

function genComboHtml(array) {
    html='';
    $.each(array, function(i,val) {
        html += '<option value="'+val+'">'+val+'</option>';
    });
    return html;
}

function readRouters() {
    $('#status').html('Bitte warten...');
    $.get('/json',{type: 'routers', start: getStart(), length: getLength()},function(data) {
        $('#routers').html(genComboHtml(data));
        $('#status').html('');
    })
}

function readClients() {
    st = getStart();
    len = getLength();

    $('#status').html('Bitte warten...');

    $.get('/json',{type: 'clients',start: st, length: len},function(data) {
        $('#clients').html(genComboHtml(data));
        $('#status').html('');
    })

}

// click handlers

function updateClick() {
  readRouters();
  readClients();
}

function averageClick() {
    drawRouterBars('raverage');
}

function uniqueClick() {
    drawRouterBars('runique');
}

function rloadClick() {
    drawRouterLoad($('#routers').val());
}

function rtimelineClick() {
    drawTimeline($('#routers').val(),'rtimeline')

}

function ltimelineClick() {
    drawTimeline($('#clients').val(),'ctimeline')
}

//executed when page is loaded
function ready() {
  //initialize datepickers and set to sane default times
  $('#from').datetimepicker();
  $('#from').datetimepicker('option','dateFormat','yy-mm-dd');
  $('#from').datetimepicker('setDate',dateToday());
  $('#to').datetimepicker();
  $('#to').datetimepicker('option','dateFormat','yy-mm-dd');
  $('#to').datetimepicker('setDate',new Date());

  $('#from').change(updateClick);
  $('#to').change(updateClick);

  $('#raverage').click(averageClick);
  $('#runique').click(uniqueClick);
  $('#rload').click(rloadClick);
  $('#rtimeline').click(rtimelineClick);
  $('#ctimeline').click(ctimelineClick);

  updateClick(); //get a list of routers and clients
}

$.ajaxSetup({timeout: 0});
$(document).ready(ready);

// Load the Visualization API and the piechart package.
google.load('visualization', '1.0', {'packages':['corechart']});

