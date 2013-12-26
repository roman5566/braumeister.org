//= require jquery
//= require jquery_ujs
//= require jquery.timeago

$(function() {
  $('abbr.timeago').timeago();

  $('#search-form').submit(function() {
    var searchUrl = '/search/' + $('#search').val();
    if(typeof(repositoryName) !== 'undefined') {
      searchUrl = '/repos/' + repositoryName + searchUrl;
    }
    window.location = searchUrl;

    return false;
  });
});
