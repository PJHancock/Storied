import {useLayoutEffect,useRef} from 'react';

export default function EditablePageText({value,editing,label,onChange,onFocus,multiline=false}:{value:string;editing:boolean;label:string;onChange:(value:string)=>void;onFocus:()=>void;multiline?:boolean}){
  const element=useRef<HTMLSpanElement>(null);
  useLayoutEffect(()=>{if(element.current&&document.activeElement!==element.current)element.current.textContent=value;},[value,editing]);
  if(!editing)return <span>{value}</span>;
  return <span ref={element} className="page-editable" contentEditable="plaintext-only" suppressContentEditableWarning role="textbox" aria-label={label} aria-multiline={multiline} tabIndex={0}
    onFocus={onFocus} onClick={event=>event.stopPropagation()}
    onKeyDown={event=>{event.stopPropagation();if(event.key==='Enter'&&!multiline){event.preventDefault();event.currentTarget.blur();}}}
    onInput={event=>onChange(event.currentTarget.innerText)} data-placeholder={label}/>;
}
