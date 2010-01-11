/* redMine - project management software
   Copyright (C) 2006-2008  Jean-Philippe Lang */

function checkAll (id, checked) {
	var els = Element.descendants(id);
	for (var i = 0; i < els.length; i++) {
    if (els[i].disabled==false) {
      els[i].checked = checked;
    }
	}
}

function toggleCheckboxesBySelector(selector) {
	boxes = $$(selector);
	var all_checked = true;
	for (i = 0; i < boxes.length; i++) { if (boxes[i].checked == false) { all_checked = false; } }
	for (i = 0; i < boxes.length; i++) { boxes[i].checked = !all_checked; }
}

function showAndScrollTo(id, focus) {
	Element.show(id);
	if (focus!=null) { Form.Element.focus(focus); }
	Element.scrollTo(id);
}

function toggleRowGroup(el) {
	var tr = Element.up(el, 'tr');
	var n = Element.next(tr);
	tr.toggleClassName('open');
	while (n != undefined && !n.hasClassName('group')) {
		Element.toggle(n);
		n = Element.next(n);
	}
}

var fileFieldCount = 1;

function addFileField() {
    if (fileFieldCount >= 10) return false
    fileFieldCount++;
    var f = document.createElement("input");
    f.type = "file";
    f.name = "attachments[" + fileFieldCount + "][file]";
    f.size = 30;
    var d = document.createElement("input");
    d.type = "text";
    d.name = "attachments[" + fileFieldCount + "][description]";
    d.size = 60;
    
    p = document.getElementById("attachments_fields");
    p.appendChild(document.createElement("br"));
    p.appendChild(f);
    p.appendChild(d);
}

function showTab(name) {
    var f = $$('div#content .tab-content');
	for(var i=0; i<f.length; i++){
		Element.hide(f[i]);
	}
    var f = $$('div.tabs a');
	for(var i=0; i<f.length; i++){
		Element.removeClassName(f[i], "selected");
	}
	Element.show('tab-content-' + name);
	Element.addClassName('tab-' + name, "selected");
	return false;
}

function setPredecessorFieldsVisibility() {
    relationType = $('relation_relation_type');
    if (relationType && relationType.value == "precedes") {
        Element.show('predecessor_fields');
    } else {
        Element.hide('predecessor_fields');
    }
}

function promptToRemote(text, param, url) {
    value = prompt(text + ':');
    if (value) {
        new Ajax.Request(url + '?' + param + '=' + encodeURIComponent(value), {asynchronous:true, evalScripts:true});
        return false;
    }
}

function collapseScmEntry(id) {
    var els = document.getElementsByClassName(id, 'browser');
	for (var i = 0; i < els.length; i++) {
	   if (els[i].hasClassName('open')) {
	       collapseScmEntry(els[i].id);
	   }
       Element.hide(els[i]);
    }
    $(id).removeClassName('open');
}

function expandScmEntry(id) {
    var els = document.getElementsByClassName(id, 'browser');
	for (var i = 0; i < els.length; i++) {
       Element.show(els[i]);
       if (els[i].hasClassName('loaded') && !els[i].hasClassName('collapsed')) {
            expandScmEntry(els[i].id);
       }
    }
    $(id).addClassName('open');
}

function scmEntryClick(id) {
    el = $(id);
    if (el.hasClassName('open')) {
        collapseScmEntry(id);
        el.addClassName('collapsed');
        return false;
    } else if (el.hasClassName('loaded')) {
        expandScmEntry(id);
        el.removeClassName('collapsed');
        return false;
    }
    if (el.hasClassName('loading')) {
        return false;
    }
    el.addClassName('loading');
    return true;
}

function scmEntryLoaded(id) {
    Element.addClassName(id, 'open');
    Element.addClassName(id, 'loaded');
    Element.removeClassName(id, 'loading');
}

function randomKey(size) {
	var chars = new Array('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z');
	var key = '';
	for (i = 0; i < size; i++) {
  	key += chars[Math.floor(Math.random() * chars.length)];
	}
	return key;
}

/* shows and hides ajax indicator */
Ajax.Responders.register({
    onCreate: function(){
        if ($('ajax-indicator') && Ajax.activeRequestCount > 0) {
            Element.show('ajax-indicator');
        }
    },
    onComplete: function(){
        if ($('ajax-indicator') && Ajax.activeRequestCount == 0) {
            Element.hide('ajax-indicator');
        }
    }
});

// show sum of estimated time
Event.observe(window, 'load', function() {
  var estimated = $$('th[title*=Estimated]');
 if(estimated.length > 0){
   estimated = estimated[0];
   var sum = ($$("td.estimated_hours").inject(0, function(sum, td){ sum = sum+parseFloat(0.0+td.innerHTML);return sum; })).toFixed(1);
   estimated.innerHTML = estimated.innerHTML + "("+sum+")";
 }
});

// Extending Prototype - getInnerText()
// http://tobielangel.com/2006/10/18/extending-prototype-getinnertext
Element.addMethods({
  getInnerText: function(element) {
    element = $(element);
    return element.innerText && !window.opera ? element.innerText
      : element.innerHTML.stripScripts().unescapeHTML().replace(/[\n\r\s]+/g, ' ');
  }
});

// Enable to append image attachments
function init_document_attachments(){
  if(!$("document_description"))return;
  $$(".attachments p").each(function(p){
    p.insert('<span class="jstElements"><button type="button" tabindex="200" class="jstb_img" title="Image"><span>Image</span></button></span>');
    p.select(".jstElements")[0].observe('click', function(){
      var button = this;
      var text = "";
      // find attachment description
      var desc = button.previous(".icon-attachment").nextSibling.nodeValue.replace(/(\s+)$/, "");
      if(desc != ""){
        text = "\n\nh3. "+desc.replace(/^( - )/, "");
      }
      // find attachment href
      var href = button.previous(".icon-attachment").readAttribute('href');
      text = text + "\n\n" +"!"+href+"!";
      // append text to textarea
      $("document_description").value = ($("document_description").value + text);
    });
  });
}

// show sum of spent time
Event.observe(window, 'load', function() {
  var spent;
  $$('#content th').each(function(e){ if(e.innerHTML == 'Spent hours')spent = e});
 if(spent){
   var sum = ($$("td.spent_hours").inject(0, function(sum, td){ sum = sum+parseFloat(td.getInnerText() == '-' ? 0.0 : td.getInnerText().replace(/ hour/, ''));return sum; })).toFixed(1);
   spent.innerHTML = spent.innerHTML + "("+sum+")";
 }

 init_document_attachments();
});
