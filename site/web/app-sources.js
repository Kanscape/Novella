(() => {
  const trigger = document.querySelector('[data-app-sources-trigger]');
  const modal = document.querySelector('[data-app-sources-modal]');
  const panel = document.querySelector('[data-app-sources-panel]');

  if (!trigger || !modal || !panel) {
    return;
  }

  const repositoryUrl = new URL(
    trigger.dataset.repositoryUrl || trigger.getAttribute('href') || 'repository.json',
    window.location.href,
  ).toString();

  const schemeBuilders = {
    altstore: (url) => `altstore-classic://source?url=${url}`,
    sidestore: (url) => `sidestore://source?url=${url}`,
    feather: (url) => `feather://source/${url}`,
  };

  const options = modal.querySelectorAll('[data-app-source-target]');
  for (const option of options) {
    const key = option.dataset.appSourceTarget;
    const buildHref = schemeBuilders[key];
    if (!buildHref) {
      continue;
    }

    option.setAttribute('href', buildHref(repositoryUrl));
  }

  const repositoryDisplay = modal.querySelector('[data-app-sources-url]');
  if (repositoryDisplay) {
    repositoryDisplay.textContent = repositoryUrl;
  }

  const fallbackLink = modal.querySelector('[data-app-sources-fallback]');
  if (fallbackLink) {
    fallbackLink.setAttribute('href', repositoryUrl);
  }

  const closeModal = () => {
    modal.classList.add('hidden');
    document.body.style.overflow = '';
    trigger.focus();
  };

  const openModal = () => {
    modal.classList.remove('hidden');
    document.body.style.overflow = 'hidden';
  };

  trigger.addEventListener('click', (event) => {
    event.preventDefault();
    openModal();
  });

  modal.addEventListener('click', (event) => {
    const target = event.target;
    if (
      target instanceof HTMLElement &&
      (target.hasAttribute('data-app-sources-close') || !panel.contains(target))
    ) {
      closeModal();
    }
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !modal.classList.contains('hidden')) {
      closeModal();
    }
  });
})();
