const trigger = document.getElementById('staff-portal-trigger');
const portal = document.querySelector('.portal-card');
const closeButton = document.querySelector('.portal-close');
const continueButton = document.querySelector('.portal-continue');

function openPortal() {
  if (!portal || !trigger) return;
  portal.classList.add('is-open');
  portal.setAttribute('aria-hidden', 'false');
  trigger.setAttribute('aria-expanded', 'true');
}

function closePortal() {
  if (!portal || !trigger) return;
  portal.classList.remove('is-open');
  portal.setAttribute('aria-hidden', 'true');
  trigger.setAttribute('aria-expanded', 'false');
}

trigger?.addEventListener('click', () => {
  const isOpen = portal?.classList.contains('is-open');
  if (isOpen) {
    closePortal();
  } else {
    openPortal();
  }
});

closeButton?.addEventListener('click', closePortal);
continueButton?.addEventListener('click', closePortal);

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && portal?.classList.contains('is-open')) {
    closePortal();
  }
});
